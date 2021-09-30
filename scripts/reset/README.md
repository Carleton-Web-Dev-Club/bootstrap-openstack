# Reset Openstack


This script connects to an openstack project, and rebuild all instances specified. This will wipe all data on them.

## Configuration
Copy the `config-sample.yml` file to `config.yml`. Modify reset.py around line 22 to customize the instance names to rebuild

You can leave the openstack password out of the config, you will be promted when the script runs.


## Running
Simple run `python3 reset.py`