#!/usr/bin/env python3
import sys,re
from openssh_wrapper import SSHConnection
def main():
    if len(sys.argv) < 2:
        print(f"{sys.argv[0]} host[,host]")
        exit(1)
    print("Paste Unseal keys here")
    data = sys.stdin.readlines()
    keys = []
    for d in data:
        if "Unseal Key" in d:
            keys.append(d.split(":")[1].strip())
    print()
    print(f"Extracted {len(keys)} keys.")
    hosts = sys.argv[1].split(",")
    
    try:
        for h in hosts:
            print(f"Connecting to {h}")
            try:
                conn = SSHConnection(h)
                v = conn.run('whoami')
                print(f"Logged in: {v}")
                for key in keys:
                    r = conn.run(f" vault operator unseal -tls-skip-verify \"{key}\"")
                    if re.search(r'Sealed\s*false', str(r)):
                        print("Unsealed")
                        break
                else:
                    print("Failed to unlock")
            except Exception as e:
                print(f"Failed to unseal {h}")
                print(e)
    except:
        print("Error")
    
        
if __name__ == "__main__":
    main()