# /etc/nomad.d/server.hcl

server {
  enabled          = true
  bootstrap_expect = {{ groups['nomad_servers'] | length }}
}
