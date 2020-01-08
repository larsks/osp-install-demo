#!/bin/sh

TEMPLATES=/usr/share/openstack-tripleo-heat-templates

deploy_args=()

if [ -f container-prepare-credentials.yaml ]; then
deploy_args+=(
	-e containers-prepare-credentials.yaml
)
fi

deploy_args+=(
	-e containers-prepare-parameter.yaml
	-n network_data.yaml

	# Node flavors and counts for the overcloud
	-e templates/node-info.yaml

	# Add the undercloud ca certificate to overcloud nodes
	-e templates/inject-trust-anchor-hiera.yaml

	# Enable HA services (pacemaker)
	-e $TEMPLATES/environments/docker-ha.yaml

	# Enable DVR, network isolation (different networks for different
	# purposes) and describe the network configuration of the overcloud
	# nodes.
	-e $TEMPLATES/environments/services/neutron-ovn-dvr-ha.yaml
	-e $TEMPLATES/environments/network-isolation.yaml
	-e $TEMPLATES/environments/network-environment.yaml
	-e templates/custom-networks.yaml

	# Pacemaker fencing configuration
	-e templates/fencing.yaml

	# Misc configuration settings
	-e templates/deploy.yaml
)

time openstack overcloud deploy \
	--templates $TEMPLATES \
	--libvirt-type kvm \
	--ntp-server 0.rhel.pool.ntp.org,1.rhel.pool.ntp.org \
	"${deploy_args[@]}" \
	"$@"
