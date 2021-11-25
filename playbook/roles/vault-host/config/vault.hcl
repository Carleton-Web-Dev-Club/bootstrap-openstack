# /etc/vault.d/vault.hcl
ui = true
service_registration "consul" {  
  address      = "127.0.0.1:8500"
  service_tags ="traefik.enable=true,traefik.http.routers.{{ consul_vault }}.entrypoints=internal-secure,traefik.http.routers.{{ consul_vault }}.rule=Host(`{{ consul_vault }}.cwdc.cbains.ca`),traefik.http.routers.{{ consul_vault }}.tls.certresolver=letsencrypt,traefik.http.services.{{ consul_vault }}.loadbalancer.server.scheme=https"
  token   = "{{ consul_vault_key_b64.content | b64decode }}"
  service = "{{ consul_vault }}" 

}
storage "consul" {

  address = "127.0.0.1:8500"
  path    = "{{ consul_vault }}"
  token   = "{{ consul_vault_key_b64.content | b64decode }}"
}

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