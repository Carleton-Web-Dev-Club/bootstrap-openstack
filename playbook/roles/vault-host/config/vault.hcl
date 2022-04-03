# /etc/vault.d/vault.hcl
ui = true
service_registration "consul" {  
  address      = "127.0.0.1:8500"
  service_tags ="traefik.enable=true,traefik.http.routers._{{ consul_vault }}.service=noop@internal,traefik.http.services.{{ consul_vault }}.loadbalancer.server.scheme=https"

  token   = "{{ consul_vault_key_b64.content | b64decode }}"
  service = "{{ consul_vault }}" 

}


{% if ha is defined and ha %}
storage "raft" {
  path = "/opt/vault-raft"
  node_id = "{{inventory_hostname}}-raft"
}
cluster_addr = "https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:8201"
api_addr = "https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:8200"
{% else %}
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "{{ consul_vault }}"
  token   = "{{ consul_vault_key_b64.content | b64decode }}"
}
{% endif %}


listener "tcp" {
  address     = "0.0.0.0:8200"
  {% if ha is defined and ha %}
  cluster_address  = "0.0.0.0:8201"
  {% endif %}
  tls_disable = 0
  tls_cert_file = "/opt/vault/vault.cert"
  tls_key_file = "/opt/vault/vault.key"
}
{% if transit is defined and transit %}
seal "transit" {  
  address = "https://active.vault-transit.service.consul:8200"  
  disable_renewal = "false"  
  key_name = "autounseal"  
  mount_path = "transit/"  
  tls_skip_verify = "true"
}
{% endif %}