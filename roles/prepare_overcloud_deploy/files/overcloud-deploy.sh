#!/bin/sh

TEMPLATES=/usr/share/openstack-tripleo-heat-templates

deploy_args=(
	-n network_data.yaml

	-e containers-prepare-credentials.yaml
	-e containers-prepare-parameter.yaml
	-e templates/node-info.yaml
	-e templates/inject-trust-anchor-hiera.yaml
	-e $TEMPLATES/environments/network-isolation.yaml
	-e $TEMPLATES/environments/network-environment.yaml
	-e $TEMPLATES/environments/docker-ha.yaml
	-e templates/custom-networks.yaml
	-e templates/extraconfig.yaml
)

openstack overcloud deploy \
	--templates $TEMPLATES \
	--libvirt-type kvm \
	--ntp-server 0.rhel.pool.ntp.org,1.rhel.pool.ntp.org \
	"${deploy_args[@]}" \
	"$@"
