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
      port "grpc_secure" {
        to = 9701
      }
      port "grpc_insecure" {
        to = -1
      }
      port "https" {
        to = 9702
      }
    }

    service {
      name = "waypoint-ui"
      port = "https"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.waypoint-server.middlewares=clear-discord-headers@consul,waypoint-auth,discord-auth@consul",
        "traefik.http.routers.waypoint-server.rule=Host(`waypoint.cwdc.carleton.ca`)",
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
      name = "waypoint-api-secure"
      port = "grpc_secure"

      check {
        type     = "tcp"
        interval = "2s"
        timeout  = "2s"
      }
    }

     service {
      name = "waypoint-api-insecure"
      port = "grpc_insecure"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.waypoint-api.rule=HostSNI(`waypoint-api.cwdc.carleton.ca`)",
        "traefik.tcp.routers.waypoint-api.tls.certresolver=letsencrypt",
        "traefik.tcp.routers.waypoint-api.entrypoints=https",
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
        ports = ["grpc_secure","https"]
      }

      resources {
        cpu    = 200
        memory = 200
      }
      
    }

    task "tls-adder" {

      restart {      
        attempts = 3      
        delay    = "5s"    
      }
      
      resources {
        cpu    = 20
        memory = 10
      }

      env {
        IN_PORT    = "${NOMAD_PORT_grpc_insecure}"
      }

      driver = "docker"

      config {
        image = "nginx"
        ports = ["grpc_insecure"]
        volumes = [
          "nginx.conf:/etc/nginx/nginx.conf"
        ]
      }


      template {
        data = <<EOF
events {
    worker_connections  1024;
}

stream   {
    upstream server_group   { {{ range service "waypoint-api-secure" }} 
        server {{ .Address }}:{{ .Port }};{{ end }}
    }

    server  {
        listen {{ env "IN_PORT" }};
        proxy_pass server_group;
        proxy_ssl  on;
        proxy_ssl_verify        off;
        
    }
}
EOF
        destination   = "nginx.conf"
        change_mode   = "restart"
      }
    }
  }
}
