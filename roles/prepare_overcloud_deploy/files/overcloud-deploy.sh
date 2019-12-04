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
	-e templates/custom-networks.yaml
)

openstack overcloud deploy \
	--templates $TEMPLATES \
	--libvirt-type kvm \
	"${deploy_args[@]}" \
	"$@"
