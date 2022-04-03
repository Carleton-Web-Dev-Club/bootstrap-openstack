job "demo-webapp" {
  datacenters = ["cwdc"]

  group "demo" {
    count = 2

    network {
      port  "http"{
        to = -1
      }
    }

    service {
      name = "demo-webapp"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wa.entrypoints=https",
        "traefik.http.routers.wa.rule=Host(`cwdc.carleton.ca`)",
        "traefik.http.routers.wa.tls.certresolver=letsencrypt",
        "routing-cwdc.carleton.ca/"
        #"traefik.http.routers.wa.middlewares=clear-discord-headers@consul,wa-svc1,discord-auth@consul",
        #"traefik.http.middlewares.wa-svc1.headers.customrequestheaders.X-cwdc-allow-ids=918617080780181604",
        # "traefik.http.middlewares.wa-svc1.headers.customrequestheaders.X-cwdc-allow-names=service-user-1"


      ]

      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }

    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      driver = "docker"

      config {
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }
    }
  }
}
