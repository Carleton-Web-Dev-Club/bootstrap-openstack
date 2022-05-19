job "ingress-control" {
  region      = "global"
  datacenters = ["cwdc"]
  #Ingress traffic is on this node
  constraint {    
    attribute = "${node.unique.name}"    
    value     = "rp-1"    
  }

  group "cert-manager" {
    count = 1

    network {
      port  "http"{
        to = 5566
      }
    }

    service {
      name = "le-challenge-server"
      port = "http"
      check {
        path     = "health"
        type     = "http"
        interval = "2s"
        timeout  = "1s"
      }
    }
    
    task "le-exporter" {
      driver = "docker"
      config {
        image = "ghcr.io/clarkbains/le-exporter:latest"
        ports = ["http"]
        network_mode = "host"
      }

      vault {        
        policies = ["le-exporter"]
        change_mode   = "restart"        
      }

      template {
        data = <<EOF
ACME_PEM_PATH=/local/privkey
CONSUL_HTTP_TOKEN={{ with secret "consul/cred/le-exporter" }}{{.Data.token}}{{ end }}
CONSUL_HTTP_HOST=consul.service.consul
VAULT_HTTP_ADDR=https://active.vault.service.consul:8200
EOF
        env = true
        destination = "local/config.env"
        change_mode   = "restart"
      }

      template {
        data = <<EOF
	{{ with secret "kv/data/projects/system/le-exporter" }}{{ .Data.data.ACCOUNT_KEY }}{{ end }}
EOF
	destination = "/local/privkey"
        change_mode   = "restart"
      }

      resources {        
        cpu    = 80 # MHz
        memory = 100 # MB      
      }
    }
  }
}
