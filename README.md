## Preqrequisites

You need a RHEL or CentOS 7 host which has access to the necessary repositories to install:

- `libvirt`
- `openvswitch`

The playbooks will install RDO repositories. These will be disabled by default but will be used to install the `virtualbmc` service.

## Setting up your inventory

Create an inventory directory with the following two files:

- `libvirt.yml` -- this is configuration for the libvirt inventory plugin (included in the `inventory_plugins` directory of this repository.
- `hosts.yml` -- this is a standard Ansible YAML-format inventory file that contains information about the libvirt host.

For example, when working with a remote machine called `neu-19-4-stackcomp.kzn.moc`, I have an inventory directory called `kzn-19-4`, and inside that directory my `hosts.yml` looks like this:

```
all:
  children:
    virthost:
      hosts:
        neu-19-4-stackcomp.kzn.moc:
          ansible_user: root
```

And my `libvirt.yml` looks like:

```
---
plugin: libvirt_inventory
uri: qemu+ssh://root@neu-19-4-stackcomp.kzn.moc/system
include_inactive: true
networks:
  - 192.168.122.0/24
loglevel: debug

compose:
  ansible_user: '"root"'
  ansible_ssh_common_args: '"-o ProxyJump=root@neu-19-4-stackcomp.kzn.moc"'

groups:
  controller: inventory_hostname.startswith('controller')
  compute: inventory_hostname.startswith('compute')
```

The use of the `qemu+ssh://...` URI provides remote access to libvirt from the machine on which I am running Ansible. If you were running these playbooks on your virthost, you could simply use `qemu:///system`.

## Things you might want to configure

There are a number of settings in `group_vars/all.yml` that control the playbooks. You may want to provide new values for:

- `rhel_image`: this is the path (and format) of a RHEL 8.1 KVM guest image (such as can be downloaded from [the Red Hat customer portal][portal]).
- `undercloud_keys`: this is a list of ssh public key URLs. If you use GitHub, `https://github.com/<username>.keys` is often a good source of your public keys. These will be used for both the `root` account and the `stack` account on the undercloud.
- `overcloud_hosts`: this dictionary describes the configuration (ram, disk, vcpus, etc) of the virtual machines created by the playbooks.

[portal]: https://access.redhat.com/downloads/content/479/ver=/rhel---8/8.1/x86_64/product-software

## Running the playbooks

You will need to point `ansible-playbook` at your inventory directory (or configure `ansible.cfg` appropriately, or set the `ANSIBLE_INVENTORY` environment variable). Because I've been working with multiple virtual environments, I just use `-i <directory>` on the `ansible-playbook` command line.

- Run `step1.yml`.

  You will need to provide the following variables:

  - `redhat_username` -- your customer portal username
  - `redhat_password` -- your customer portal password
  - `redhat_pool_ids` -- a list of pool to which your system should be attached

  I drop these into a file named `credentials.yml`...

  ```
  ---
  redhat_username: myusername@redhat.com
  redhat_password: secretpassword
  redhat_pool_ids:
    - 12345678909876543210c323263339ff
  ```

  ...and pass that it on the `ansible-playbook` command line:

  ```
  ansible-playbook step1.yml -i kzn-19-4 -e @credentials.yml
  ```

- Log into the undercloud and run `openstack undercloud install` as the `stack` user

  To log into the undercloud, I first get the ip address from the virt host:

  ```
  # virsh domifaddr undercloud
   Name       MAC address          Protocol     Address
  -------------------------------------------------------------------------------
   vnet0      52:54:00:6b:8d:e0    ipv4         192.168.122.76/24
  ```

  And then log in as the `stack` user:

  ```
  # ssh stack@192.168.122.76
  [stack@undercloud ~]$ openstack undercloud install
  ```

  This should take around 30 minutes to complete.

- Run `step2.yml`
- Run `step3.yml`
- Run `step4.yml`
- Log into the undercloud and run `sh overcloud-deploy.sh`.

  I usually capture the output from the command for later review if somethings goes wrong:

  ```
  # ssh stack@192.168.122.76
  [...]
  [stack@undercloud ~]$ script -c 'sh overcloud-deploy.sh'
  ```

  This should take around an hour to complete.

- Run `step5.yml`. This will set up resources for testing the install (an image, a flavor, networks, etc). It also sets up a `clouds.yaml` file on the undercloud, so  you can specify credentials to commands using the `--os-cloud` option:

  ```
  $ openstack --os-cloud undercloud server list
  $ openstack --os-cloud overcloud hypervisor list
  ```

  In addition to the `undercloud` and `overcloud` clouds, it will create an `overcloud-<user>` entry for any users created by the playbook (currently, just the `demo` user).

## Network configuration

The controller and compute guests created by these playbooks are attached to the following networks:

- eth0: provisioning network (vlan 100)
- eth0.101: internal api (vlan 101)
- eth0.102: tenant private (vlan 102)
- eth1: management/ipmi
- eth2: storage (vlan 103)
- eth3: external network (vlan 200)
- eth4: floating ip (vlan 201)
