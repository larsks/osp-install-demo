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

- `undercloud_keys`: this is a list of ssh public key URLs. If you use GitHub, `https://github.com/<username>.keys` is often a good source of your public keys. These will be used for both the `root` account and the `stack` account on the undercloud.
- `overcloud_hosts`: this dictionary describes the configuration (ram, disk, vcpus, etc) of the virtual machines created by the playbooks.

## Running the playbooks

You will need to point `ansible-playbook` at your inventory directory (or configure `ansible.cfg` appropriately, or set the `ANSIBLE_INVENTORY` environment variable). Because I've been working with multiple virtual environments, I just use `-i <directory>` on the `ansible-playbook` command line.

- Run `step1.yml`.

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

  Or by setting the `OS_CLOUD` environment variable.

  In addition to the `undercloud` and `overcloud` clouds, it will create an `overcloud-<user>` entry for any users created by the playbook (currently, just `overcloud-demo` for the `demo` user).

## Network configuration

The controller and compute guests created by these playbooks are attached to the following networks:

- eth0: provisioning network (vlan 100)
- eth0.101: internal api (vlan 101)
- eth0.102: tenant private (vlan 102)
- eth1: management/ipmi
- eth2: storage (vlan 103)
- eth3: external network (vlan 200)
- eth4: floating ip (vlan 201)

These interfaces are all plumbed to an Open vSwitch switch on the virthost named "openstack". At a high level, the virtual infrastructure looks like this:

```
+-------------+     +-------------+     +-------------+
|             |     |             |     |             |
| controller0 |     | controller1 |     | controller2 |
|             |     |             |     |             |
+-----+-------+     +-------+-----+     +-------+-----+
      |                     |                   |
      +-------------+       |      +------------+
                    |       |      |
               +----+-------+------+----+       +------------+
      extgw----+                        |       |            |
               |  openstack ovs switch  +-------+ undercloud |
    floatgw----+                        |       |            |
               +--------+--------+------+       +------------+
                        |        |
                 +------+        +------+
                 |                      |
          +------+------+          +----+--------+
          |             |          |             |
          | compute0    |          | compute1    |
          |             |          |             |
          +-------------+          +-------------+
```

`extgw` and `floatgw` are interfaces on the virt host that act as the default gateways for, respectively, the external network and the floating ip network.

## Some notes on the demo environment

### Getting a list of deployed servers

Run `openstack server list` against the undercloud to a get a list of deployed servers and their addresses.  You can source in the `stackrc` file first:

```
. ./stackrc
openstack server list -c Name -c Networks
```

Or you can set the `OS_CLOUD` environment variable:


```
export OS_CLOUD=undercloud
openstack server list -c Name -c Networks
```

The latter takes advantage of the `~/.config/openstack/clouds.yaml` created by the demo playbooks.

Either of the above commands will result in something like:

```
+-------------------------+------------------------+
| Name                    | Networks               |
+-------------------------+------------------------+
| overcloud-novacompute-0 | ctlplane=192.168.24.12 |
| overcloud-controller-2  | ctlplane=192.168.24.15 |
| overcloud-controller-0  | ctlplane=192.168.24.13 |
| overcloud-controller-1  | ctlplane=192.168.24.22 |
| overcloud-novacompute-1 | ctlplane=192.168.24.7  |
+-------------------------+------------------------+
```

From the `stack` account on the `undercloud` host you can ssh to any of those addresses:

```
[stack@undercloud ~]$ ssh 192.168.24.13 sudo pcs status
Warning: Permanently added '192.168.24.13' (ECDSA) to the list of known hosts.
Cluster name: tripleo_cluster
Stack: corosync
Current DC: overcloud-controller-0 (version 1.1.20-5.el7_7.2-3c4c782f70) - partition with quorum
Last updated: Mon Feb  3 17:14:34 2020
Last change: Wed Jan  8 18:24:56 2020 by root via cibadmin on overcloud-controller-0

15 nodes configured
50 resources configured

Online: [ overcloud-controller-0 overcloud-controller-1 overcloud-controller-2 ]
GuestOnline: [ galera-bundle-0@overcloud-controller-0 galera-bundle-1@overcloud-controller-1 galera-bundle-2@overcloud-controller-2 ovn-dbs-bundle-0@overcloud-controller-0 ovn-dbs-bundle-1@overcloud-controller-1 ovn-dbs-bundle-2@overcloud-controller-2 rabbitmq-bundle-0@overcloud-controller-0 rabbitmq-bundle-1@overcloud-controller-1 rabbitmq-bundle-2@overcloud-controller-2 redis-bundle-0@overcloud-controller-0 redis-bundle-1@overcloud-controller-1 redis-bundle-2@overcloud-controller-2 ]

Full list of resources:
[...]
```


### Demo user credentials

The `step5.yml` playbook in the demo repository creates a `demo` user and a few additional OpenStack resources (images, flavors, etc) so that you have something to play with.  The credentials for the `demo` user are stored in `~/.config/openstack/clouds.yaml` on the undercloud. If you log into the undercloud, you can run:

```
export OS_CLOUD=overcloud-demo
```

And as long as you have `OS_CLOUD` set in your environment, the `openstack` cli will use the corresponding credentials from that `clouds.yaml` file.

### Creating a server

You can create a server as the `demo` user by running:

```
openstack server create --key-name default --image centos-7-x86_64 \
  --flavor m1.tiny --nic net-id=net0 demoserver
```

If you want to be able to log into that server, you'll first need to allocate a floating ip from the `public` network:

```
openstack floating ip create public
```

And then associate that with the server we just created. Assuming that we were assigned `10.1.0.225`:

```
openstack server add floating ip demoserver 10.1.0.225
```

You should now be able to ssh into that server:

```
ssh centos@10.1.0.225
```

Note that the route from the undercloud to that server is via the `floatgw` interface that was created on the hypervisor host by the `libvirt` role in the demo repository.

### Accessing the demo environment from your local system

If you'd like to access the demo OpenStack environment from your local system, the [sshuttle][] tool (available as a package in Fedora) offers a convenient solution.  Assuming that `10.0.0.0/24` and `10.1.0.0/24` don't conflict with your local networks, just run the following command:

```
sshuttle -D -r you@your_hyppervisor_host 10.0.0.0/24 10.1.0.0/24
```

Now you can copy that `clouds.yaml` file to your local system and run the `openstack` cli locally, or point your browser at Horizon running on the overcloud (the url will be the same as the `auth_url`, but drop the port number).

[sshuttle]: https://github.com/sshuttle/sshuttle

## More about OVN

Networking on the overcloud is realized through OVN ("__O__ pen  __V__ irtual  __N__ etwork"). I wrote a little about OVN and how it operates here:

- "[OVN and DHCP: A minimal example](https://blog.oddbit.com/post/2019-12-19-ovn-and-dhcp/)"

You'll find links to more articles here:

- https://docs.openstack.org/networking-ovn/latest/admin/ovn.html
- https://developers.redhat.com/blog/tag/ovn/

You can inspect the high-level OVN configuration by logging into one of your controllers and running, as root:

```
ovn_vip=$(jq -r '."tripleo::keepalived::ovndbs_virtual_ip"' /etc/puppet/hieradata/vip_data.json)
docker exec ovn_controller ovn-nbctl --db tcp:${ovn_vip}:6641 show
```

The above `ovn-nbctl` command interact with the OVN "northbound" database, which defines the logical structure of the OVN network. The output will look something like this:

```
switch 8a3e8c30-6bb7-4442-9e88-172397f934fd (neutron-0dbd0c9b-b3b4-4f74-b4b9-99009fc2e3f8) (aka net0)
    port 3311934f-0584-46e5-911e-2b0970f07d98
        type: localport
        addresses: ["fa:16:3e:a5:7b:78 192.168.17.10"]
    port 3fc94161-2c62-40c3-9931-ada91420d9b9
        addresses: ["fa:16:3e:79:b6:93 192.168.17.93"]
    port 3fe202b9-e907-44e2-b42f-3e016270e7be
        type: router
        router-port: lrp-3fe202b9-e907-44e2-b42f-3e016270e7be
switch 2b6f3c75-9474-45c9-a059-2d6c6a85f5de (neutron-a5d2bfac-e2b9-4025-8f7c-b91c25dbf02f) (aka public)
    port provnet-a5d2bfac-e2b9-4025-8f7c-b91c25dbf02f
        type: localnet
        addresses: ["unknown"]
    port 48de833f-b1e4-41cb-9d06-8c6462e78d5b
        type: router
        router-port: lrp-48de833f-b1e4-41cb-9d06-8c6462e78d5b
    port a6a9d2c8-41e6-4aa8-8271-5965959933a0
        type: localport
        addresses: ["fa:16:3e:a8:a0:9a"]
router 309ac65b-15a9-489f-a191-3cdb67913282 (neutron-99ad4d90-24f7-480e-a3ca-45f6379a6632) (aka router0)
    port lrp-48de833f-b1e4-41cb-9d06-8c6462e78d5b
        mac: "fa:16:3e:03:ea:2a"
        networks: ["10.1.0.66/24"]
        gateway chassis: [a4461a9f-15f4-4650-a17e-740d59b153a0 c225dfe1-0718-4a53-ac6e-0e736a49fff5 c18bc847-cdbc-401d-8f5f-a28aad189df8]
    port lrp-3fe202b9-e907-44e2-b42f-3e016270e7be
        mac: "fa:16:3e:af:0b:2b"
        networks: ["192.168.17.1/24"]
    nat 772f207b-ad35-4c80-8263-f18e36a86707
        external ip: "10.1.0.66"
        logical ip: "192.168.17.0/24"
        type: "snat"
    nat b5b5952d-ad5b-4c1e-b6cd-90b6a88d8e42
        external ip: "10.1.0.225"
        logical ip: "192.168.17.93"
        type: "dnat_and_snat"
```

To access the OVN "southbound" database, use `ovn-sbctl` and port `6642`:

```
docker exec ovn_controller ovn-sbctl --db tcp:${ovn_vip}:6642 show
```

## Additional documentation

There is a CLI cheat sheet available for the Ocata release of OpenStack:

- https://docs.openstack.org/ocata/user-guide/cli-cheat-sheet.html

That's a few releases behind, but still provides a reasonable overview of common end-user commands.

There are [administration guides][] for most OpenStack services. Of particular interest are probably:

- [Cinder](https://docs.openstack.org/cinder/train/admin/)
- [Glance](https://docs.openstack.org/glance/train/admin/)
- [Keystone](https://docs.openstack.org/keystone/train/admin/)
- [Neutron](https://docs.openstack.org/neutron/train/admin/)
- [Nova](https://docs.openstack.org/nova/train/admin/)
- [Swift](https://docs.openstack.org/swift/train/admin/)

[administration guides]: https://docs.openstack.org/train/admin/
