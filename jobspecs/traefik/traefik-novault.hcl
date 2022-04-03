# Inspired from https://github.com/CarletonComputerScienceSociety/cloud-native/blob/main/nomad/traefik/traefik.hcl
job "traefik" {
  region      = "global"
  datacenters = ["cwdc"]
  #Ingress traffic is on this node
  constraint {    
    attribute = "${node.unique.name}"    
    value     = "nc-1"    
  }
  group "traefik" {
    count = 1

   # volume "certs" {
   #   type      = "csi"
   #   attachment_mode = "file-system"
   #   access_mode     = "multi-node-multi-writer"
   #   source    = "traefik-certs"
   # }

    network {
      port "http" {
        static = 80
      }
      
      port "https" {
        static = 443
      }
      
      port "internal" {
        static = 8081
      }
      
      port "internal-secure" {
        static = 4443
      }

    }

    service {
      name = "traefik"
      
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }
    ephemeral_disk {
      migrate = true
      size    = 200
      sticky  = true
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:latest"
        network_mode = "host"
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml"
          ]
      }
      #vault {        
      #  policies = ["traefik"]
      #}

     # volume_mount {
     #   volume      = "certs"
     #   destination = "/data"
     # }

      template {
        data = <<EOF
# Allow backends to use self signed ssl certs (Needed for waypoint)
[serversTransport]
  insecureSkipVerify = true
[entryPoints]
    [entryPoints.http]
    address = ":80"
    [entryPoints.https]
    address = ":443"
    [entryPoints.internal-secure]
    address = ":4443"

[api]
    dashboard = true
    insecure = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false
    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
[providers.consul]
    rootKey = "traefik"
    endpoints = ["127.0.0.1:8500"]
    token = "5220070b-62e9-e6e4-48da-27e52e2c7c1a"

[certificatesresolvers.letsencrypt.acme]
  email = "clarkbains@gmail.com"
  storage = "/alloc/data/acme.json"
  [certificatesresolvers.letsencrypt.acme.httpchallenge]
    entrypoint = "http"
EOF

        destination = "local/traefik.toml"
        change_mode   = "restart"
      }
 
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
