import os,getpass, subprocess,json
from typing import Mapping


def validateConfig(config, test=True):
    if "env" not in config:
        print("WARN: no env in openstack config")
        return False
    for key in config["env"]:
        if key in os.environ:
            print("Overwriting config with {} from env".format(key))
            config["env"][key] = os.environ[key]
    if not config["env"].get("OS_PASSWORD", None):
         config["env"]["OS_PASSWORD"] = getpass.getpass("Openstack Password: ")
    if not test:
        return True
    try:
        res = runOpenstackCommand(config, ["server list"])
        if not res:
            return False
        return True
    except Exception as e:
        print(e)
        pass
    return False


def runOpenstackCommand(config, command, parseOutput=True):
    cmd = ["/usr/local/bin/openstack"] + command
    if (parseOutput):
        cmd = ["/usr/local/bin/openstack"] + command + ["-f", "json"]
    res = subprocess.check_output(cmd, env=config['env']).decode("UTF-8")
    if len(res) == 0 or not parseOutput:
        return None
    return json.loads(res)
