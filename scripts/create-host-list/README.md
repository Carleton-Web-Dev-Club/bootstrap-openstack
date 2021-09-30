# Create Host List

DHCP, but worse.


This script connects to an openstack instance, and gathers all the IPs for a project. It then checks if they are in a configurable subnet, and will then append them to the end of the "hosts.prepend" file, and write to a customizable location

## Configuration
Copy the `config-sample.yml` file to `config.yml`. Add any static configurations to the `hosts.prepend` file. `hosts.prepend.ansible` provides an example for using the ansible template task to add in the machine's hostname.

You can leave the openstack password out of the config, you will be promted when the script runs.

### Ansible
Set the output location to be in ansible's config folder, then use something like the following task
```
    - name: Copy Hosts File
      template: 
        src: config/hosts/hosts
        dest: /etc/hosts
```
## Running
Simple run `python3 create.py`