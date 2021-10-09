job "mysql-server" {
  datacenters = ["cwdc"]
  type        = "service"
  group "mysql-server" {
    count = 1
    volume "ceph-mysql" {
      type      = "csi"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      read_only = false
      source    = "ceph-mysql"
    }
    network {
      port "db" {
        static = 3306
      }
    }
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    task "mysql-server" {
      driver = "docker"
      volume_mount {
        volume      = "ceph-mysql"
        destination = "/srv"
        read_only   = false
      }
      env {
        MYSQL_ROOT_PASSWORD = "password"
      }
      config {
        image = "hashicorp/mysql-portworx-demo:latest"
        args  = ["--datadir", "/srv/mysql"]
        ports = ["db"]
      }
      resources {
        cpu    = 500
        memory = 1024
      }
      service {
        name = "mysql-server"
        port = "db"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
