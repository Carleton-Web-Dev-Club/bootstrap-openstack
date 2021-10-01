datacenter = "cwdc-os-1"
data_dir = "/opt/consul"
encrypt = "{{ consul_key_b64.content | b64decode | trim}}"
verify_incoming = false
verify_outgoing = false
verify_server_hostname = false
retry_join = ["{{ ip.stdout }}"]
ui = true
