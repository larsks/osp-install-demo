#!/usr/bin/python

'''This script generates a nodes.json suitable for use with the
`openstack overcloud node import` command by interrogating libvirt and
virtualbmc.'''

import argparse
import json
import libvirt
import lxml.etree
import subprocess
import sys


class Libvirt:
    def __init__(self, uri=None):
        self.conn = libvirt.open(uri)

    def all_nodes(self):
        '''Yield information for all discovered libvirt guests'''

        for dom in self.conn.listAllDomains():
            yield self.node(dom.name())

    def node(self, name):
        '''Get libvirt and virtualbmc information for a single node'''

        dom = self.conn.lookupByName(name)
        domxml = lxml.etree.fromstring(dom.XMLDesc(
            flags=libvirt.VIR_DOMAIN_XML_INACTIVE))
        bmcinfo = self._get_vbmc_info(name)

        data = {
            'name': name,
            'mac': domxml.xpath(
                '/domain/devices/interface[source/@bridge = "openstack"]'
                '/mac/@address')[:1],
            'pm_type': 'ipmi',
            'pm_user': 'admin',
            'pm_password': 'password',
            'pm_addr': '192.168.122.1',
            'pm_port': bmcinfo.get('port', 623),
        }

        if not data['mac']:
            data['mac'] = domxml.xpath(
                '/domain/devices/interface[source/@portgroup = "internal"]'
                '/mac/@address')[:1]

        return data

    def _get_vbmc_info(self, name):
        '''Get virtualbmc information for the named node'''
        try:
            out = subprocess.check_output(['vbmc', 'show', name, '-f', 'json'])
        except subprocess.CalledProcessError:
            return {}

        info = json.loads(out)

        properties = {}
        for prop in info:
            properties[prop['Property']] = prop['Value']

        return properties


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('-o', '--output')
    return p.parse_args()


if __name__ == '__main__':
    args = parse_args()

    lv = Libvirt()
    nodes = [node for node in lv.all_nodes()
             if 'undercloud' not in node['name']]

    with (open(args.output, 'w') if args.output else sys.stdout) as fd:
        json.dump(nodes, fd, indent=2)
