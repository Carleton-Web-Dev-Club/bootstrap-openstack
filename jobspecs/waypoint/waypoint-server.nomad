job "waypoint-server" {
  datacenters = ["cwdc"]
  type        = "service"
  group "server" {
    count = 1
    
    volume "ceph-waypoint" {
      type      = "csi"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
      source    = "waypoint-data"
    }

    network {
      port "grpc" {
        static = 9701
      }
      port "https" {
        static = 9702
      }
      mode= "host"
    }
    service {
      name = "waypoint-ui"
      port = "https"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.waypoint-server.middlewares=clear-discord-headers@consul,waypoint-auth,discord-auth@consul",
        "traefik.http.routers.waypoint-server.rule=Host(`waypoint.cwdc.cbains.ca`)",
        "traefik.http.services.waypoint-server.loadbalancer.server.scheme=https",
        "traefik.http.routers.waypoint-server.tls.certresolver=letsencrypt",
        "traefik.http.routers.waypoint-server.entrypoints=https",
        "traefik.http.middlewares.waypoint-auth.headers.customrequestheaders.X-cwdc-allow-ids=928496196295749632"
      ]

      check {
        type     = "http"
        tls_skip_verify = true
        interval = "2s"
        timeout  = "2s"
        protocol = "https"
        path     = "/"
      }
    }
    service {
      name = "waypoint-api"
      port = "grpc"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.waypoint-api.rule=HostSNI(`waypoint-api.cwdc.cbains.ca`)",
        "traefik.tcp.routers.waypoint-api.tls.passthrough=true",
        "traefik.tcp.routers.waypoint-api.entrypoints=https"
      ]

      check {
        type     = "tcp"
        interval = "2s"
        timeout  = "2s"
      }
    }
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }


    task "waypoint-server" {
      driver = "docker"
      volume_mount {
        volume      = "ceph-waypoint"
        destination = "/data"
        read_only   = false
      }
      config {
        image = "hashicorp/waypoint:latest"
        args  = [
              "server",
              "run",
              "-accept-tos",
              "-vv",
              "-db=/data/data.db",
              "-listen-grpc=0.0.0.0:9701",
              "-listen-http=0.0.0.0:9702"
            ]
        ports = ["grpc","https"]
        network_mode = "host"
      }

      resources {
        cpu    = 500
        memory = 512
      }
      
    }
  }
}
