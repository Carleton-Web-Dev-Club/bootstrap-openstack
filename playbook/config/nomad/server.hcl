# /etc/nomad.d/server.hcl

# data_dir tends to be environment specific.
datacenter = "cwdc"
data_dir = "/opt/nomad/data"
server {
  enabled          = true
  bootstrap_expect = {{ groups['servers'] | length }}
}
