datacenter = "cwdc"
data_dir = "/opt/consul"
encrypt = "{{ consul_key_b64.content | b64decode | trim}}"
verify_incoming = false
verify_outgoing = false
verify_server_hostname = false
retry_join = ["{{ leader_ip }}"]
advertise_addr = "{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}"
bind_addr = "0.0.0.0"
domain = "consul"
acl {  
    enabled        = true  
    default_policy = "deny"  
    down_policy    = "extend-cache"
    enable_token_persistence = true
}
enable_script_checks = true