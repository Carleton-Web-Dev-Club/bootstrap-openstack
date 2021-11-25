node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
# only needed if using prepared queries
query_prefix "" {
  policy = "read"
}
key_prefix "traefik" {
  policy = "read"
}

session "" {
  policy = "write"
}

agent_prefix "" {
  policy = "read"
}



