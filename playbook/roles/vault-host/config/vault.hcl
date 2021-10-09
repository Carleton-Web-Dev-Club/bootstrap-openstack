# /etc/vault.d/vault.hcl


storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
  token   = "{{ consul_vault_key_b64.content | b64decode }}"
}

listener "tcp" {
  address     = "0.0.0.0:8500"
  cluster_address  = "0.0.0.0:8201"
  tls_disable = 0
}
