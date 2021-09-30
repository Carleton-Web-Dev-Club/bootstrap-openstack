#!/usr/bin/env python3
import sys
import yaml,os, ipaddress
from importlib.machinery import SourceFileLoader
openstack = SourceFileLoader("openstack", os.path.join(sys.path[0],"../lib/openstack.py")).load_module()


def genHosts(config, servers):
    res = ""

    subnetConfig = config.get('subnet', '192.168.0.0/16')
    subnet = ipaddress.ip_network(subnetConfig)

    prepend = open(os.path.join(sys.path[0],"hosts.prepend"))
    res+= prepend.read() + "\n"
    prepend.close()

    for server in sorted(servers,key= lambda x : x['Name']):
        ipList = []
        for ipNetworks in server['Networks'].values():
            for ip in ipNetworks:
                if ipaddress.ip_address(ip) in subnet:
                    ipList.append(ip)
        name = server['Name']
        print("Writing hosts definitions for host: {} in subnet {}".format(name, subnetConfig))
        for ip in ipList:
            res+= "{}\t{}\n".format(ip, name)
    return res


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
    
    hosts = genHosts(config['openstack'], servers)
    writeLocation = config.get('output',{}).get('location','/tmp/hosts')
    f = open(writeLocation,"w")
    f.write(hosts)
    f.close
    print("Hosts file has been written to {}".format(writeLocation))

if __name__ == "__main__":
    main()