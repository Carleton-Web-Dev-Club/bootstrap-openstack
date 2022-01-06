# /etc/nomad.d/server.hcl

server {
  enabled          = true
  bootstrap_expect = {{ groups['nomad_servers'] | length }}
}

vault {
  enabled          = true
  address          = "https://active.vault.service.consul:8200"
  create_from_role = "nomad-cluster"
  #allow_unauthenticated = false
  tls_skip_verify = true
  token = "{{ NOMAD_VAULT_TOKEN  }}"
}

acl {
  enabled = true
}