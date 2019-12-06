## Running the playbooks:

- Run `step1.yml`.
- Log into the undercloud and run `openstack undercloud install`
- Run `step2.yml`
- Run `step3.yml`
- Run `step4.yml`
- Log into the undercloud and run `sh overcloud-deploy.sh`

You will need to provide the following variables:

- `redhat_username` -- your customer portal username
- `redhat_password` -- your customer portal password
- `redhat_pool_ids` -- a list of pool to which your system should be attached

## Network configuration

- eth0: provisioning network (vlan 100)
- eth0.101: internal api (vlan 101)
- eth0.102: tenant private (vlan 102)
- eth1: management/ipmi
- eth2: storage (vlan 103)
- eth3: external network (vlan 200)
- eth4: floating ip (vlan 201)
