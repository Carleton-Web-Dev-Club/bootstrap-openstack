bootstrap_expect = {{ groups['consul_servers'] | length }}
server = true
client_addr = "0.0.0.0"
ui = true