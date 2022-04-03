job "fabio" {
  region      = "global"
  datacenters = ["cwdc"]
  #Ingress traffic is on this node
  constraint {    
    attribute = "${node.unique.name}"    
    value     = "rp-1"    
  }
  group "fabio" {
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

   # service {
   #   name = "fabio"
   #   port = "http"
   #   check {
   #     name     = "alive"
   #     type     = "tcp"
   #     port     = "http"
   #     interval = "10s"
   #     timeout  = "2s"
   #   }
   # }


    task "fabio" {
      driver = "docker"

      config {
        image        = "fabiolb/fabio:latest"
        network_mode = "host"
        args  = [
              "-cfg",
              "/etc/fabio.conf"
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
ui.access = rw
log.access.target = stdout
proxy.cs = cs=vaultcerts;type=vault;cert=kv/infrastructure/le-certs
proxy.addr =:80;proto=http;
proxy.addr =:443;proto=https;cs=vaultcerts
registry.custom.checkTLSSkipVerify = true
registry.consul.tagprefix=routing=
registry.consul.token = {{ with secret "consul/creds/fabio"}}{{.Data.token}}{{ end }}
ui.addr = :9998
EOF

        destination = "local/fabio.conf"
        change_mode   = "restart"
      }

#
#vault token create -policy fabio -period 7200h
            template {
        data = <<EOF
VAULT_ADDR=https://active.vault.service.consul:8200
VAULT_SKIP_VERIFY=TRUE
V1AULT_TOKEN=s.Czg7FsgiuQEL41ErbafF3RSL
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
  }
}
