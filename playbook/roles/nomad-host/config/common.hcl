# /etc/nomad.d/common.hcl

# data_dir tends to be environment specific.
datacenter = "cwdc"
data_dir = "/opt/nomad/data"


consul {
  token = "{{ consul_nomad_key_b64.content | b64decode | trim  }}"
}