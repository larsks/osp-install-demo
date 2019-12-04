## Running the playbooks:

- Run `step1.yml`.
- Log into the undercloud and run `openstack undercloud install`
- Run `step2.yml`
- Run `step3.yml`
- Run `step4.yml`
- Log into the undercloud and run `sh overcloud-deploy.sh`

## Network configuration

- eth0: provisioning network
- eth0.101: internal api
- eth0.102: tenant private
- eth1: management/ipmi
- eth2: external network
- eth3: floating ip
