job "discord-auth-proxy" {
  datacenters = ["cwdc"]
  group "server" {
    count = 1

    network {
      port  "http"{
        static = 8888
      }
    }

    service {
      name = "auth-proxy-frontend"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.auth-proxy.rule=Host(`oauth.cwdc.carleton.ca`)",
        "traefik.http.routers.auth-proxy.tls.certresolver=letsencrypt",
        "traefik.http.routers.auth-proxy.entrypoints=https",
      ]
      check {
        path     = "/health"
        type     = "http"
        interval = "2s"
        timeout  = "1s"
      }
    }
    
    task "server" {
      driver = "docker"
      config {
        image = "${artifact.image}:${artifact.tag}"
        ports = ["http"]
      }
      vault {        
        policies = ["discord-proxy"]
        change_mode   = "restart"        
      }

      template {
        data = <<EOH
{{ with secret "kv/projects/system/discord-auth" }}
{{ range $key, $pairs := .Data.data | explodeMap }}
{{ $key }}="{{ $pairs }}"
{{- end }}
{{ end}}
        EOH
        destination = "local/file.env"
        change_mode   = "restart"
        env         = true
        }
      resources {        
        cpu    = 40 # MHz
        memory = 100 # MB      
      }
    }
  }
}
