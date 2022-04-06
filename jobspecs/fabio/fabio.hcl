job "ingress-control" {
  region      = "global"
  datacenters = ["cwdc"]
  #Ingress traffic is on this node
  constraint {    
    attribute = "${node.unique.name}"    
    value     = "rp-1"    
  }
  group "loadbalancing" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "ui" {
        static = 9998
      }
    }

    service {
      name = "fabio"
      port = "ui"
      check {
        name     = "alive"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "routing=traefik.cwdc.carleton.ca/",
      ]
    }

    task "fabio-secure" {
      driver = "docker"

      config {
        image        = "fabiolb/fabio:latest"
        network_mode = "host"
        args  = [
              "-cfg",
              "/etc/fabio.conf",
              "-insecure"
            ]
        volumes = [
          "local/fabio.conf:/etc/fabio.conf"
          ]
        
      }
      vault {        
        policies = ["fabio"]
      }

      template {
        data = <<EOF
ui.access=ro
log.access.target=
proxy.cs= cs=vaultcerts;type=vault;cert=kv/infrastructure/le-certs
proxy.addr=:443;proto=https;cs=vaultcerts
proxy.matcher=iprefix
registry.consul.service.status=passing,unknown
registry.custom.checkTLSSkipVerify=true
registry.consul.tagprefix=routing=
registry.consul.token={{ with secret "consul/creds/fabio"}}{{.Data.token}}{{ end }}
registry.consul.register.enabled=false
ui.addr = :9998

EOF

        destination = "local/fabio.conf"
        change_mode   = "restart"
      }

            template {
        data = <<EOF
VAULT_ADDR=https://active.vault.service.consul:8200
VAULT_SKIP_VERIFY=TRUE
EOF
        destination = "local/fabio.env"
        env = true
        change_mode   = "restart"
      }
 
      resources {
        cpu    = 500
        memory = 500
      }
    }


    task "fabio-redirector" {
      driver = "docker"
      config {
        image        = "fabiolb/fabio:latest"
        ports  = ["http"]
        args  = [
              "-cfg",
              "/etc/fabio.conf",
              "-insecure"
            ]
        volumes = [
          "local/fabio.conf:/etc/fabio.conf"
          ]
      }

      template {
        data = <<EOF
ui.access=ro
log.access.target=
proxy.addr=:80;proto=http
registry.backend = static
proxy.matcher=glob
registry.static.routes = route add https-redirect *:80/* https://$host$path opts "redirect=301"
EOF
        destination = "local/fabio.conf"
        change_mode   = "restart"
      }

      resources {
        cpu    = 50
        memory = 20
      }
    }

  }
}
