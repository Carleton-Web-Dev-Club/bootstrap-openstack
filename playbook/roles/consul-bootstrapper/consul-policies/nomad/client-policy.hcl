agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}

key_prefix "nomad" {
  policy = "read"
}

acl = "write"
