#!/usr/bin/env python3
import sys
import yaml,os, ipaddress
from importlib.machinery import SourceFileLoader
openstack = SourceFileLoader("openstack", os.path.join(sys.path[0],"../lib/openstack.py")).load_module()




def main():
    yamlFile=open(os.path.join(sys.path[0],"config.yml"))
    try:
        config = yaml.safe_load(yamlFile.read())['config']
    except Exception as e:
        print("Error while parsing config", e)
        sys.exit(1)
    if not openstack.validateConfig(config['openstack'], False):
        print("Error validating openstack config")
        sys.exit(1)
    servers = openstack.runOpenstackCommand(config['openstack'],["server list"])
    for serve in servers:
        if serve['Name'].startswith("nc") or serve['Name'].startswith("ns") or serve['Name'] == "backup":
            print (serve['Name'], serve['ID'])
            openstack.runOpenstackCommand(config['openstack'],["server", "rebuild", serve['ID']], False)

if __name__ == "__main__":
    main()