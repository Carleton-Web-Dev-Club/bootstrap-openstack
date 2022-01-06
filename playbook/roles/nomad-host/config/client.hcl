# /etc/nomad.d/client.hcl


client {
  enabled = true
}

plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}

vault {
  enabled          = true
  address          = "https://active.vault.service.consul:8200"
  create_from_role = "nomad-cluster"
  #allow_unauthenticated = false
  tls_skip_verify = true
}
