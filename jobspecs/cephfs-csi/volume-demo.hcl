#HTTP example, but with a mounted volume. Exec into more than one of the allocs, and watch as /data is changed for all allocs whenever one makes a change
job "demo-volume-app" {
  datacenters = ["cwdc"]
  type        = "service"
  group "server" {
    count = 3
    
    volume "tv" {
      type      = "csi"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
      read_only = false
      source    = "test-volume"
    }
     network {
      port  "http"{
        to = -1
      }
    }

    service {
      name = "demo-webapp"
      port = "http"
    }

    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }
      volume_mount {
        volume      = "tv"
        destination = "/data"
        read_only   = false
      }

      driver = "docker"

      config {
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }
    }
  }
}
