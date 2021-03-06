# /etc/nomad.d/client.hcl

datacenter = "cwdc"

# data_dir tends to be environment specific.
data_dir = "/opt/nomad/data"
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
