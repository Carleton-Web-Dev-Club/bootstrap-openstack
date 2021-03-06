job "cephfs-csi-plugin-controller" {
  datacenters = ["cwdc"]
  group "controller" {
    restart {
      attempts = 3
      delay    = "1m"
      interval = "10m"
      mode     = "delay"
    }

    task "ceph-controller" {
      template {
        data        = <<EOF
[{
    "clusterID": "ab0a7bf8-c0f0-49a1-a0c7-c8e44d83b3c7",
    "monitors": [
        "192.168.25.137",
        "192.168.25.159",
        "192.168.25.253"
    ]
}]
EOF
        destination = "local/config.json"
        change_mode = "restart"
      }
      
      template {
        #Ugly workaround to cause it to restart when there is a ceph-data in warning state.
        data        = <<EOF
  {{ $result := service "ceph-data" }}{{ if not $result }}PARSER ERROR{{end}}
EOF
        destination = "secrets/file.env"
        change_mode = "restart"
        env = true
      }
      
      driver = "docker"
      config {
        image = "quay.io/cephcsi/cephcsi:v3.4.0"
        volumes = [
          "./local/config.json:/etc/ceph-csi-config/config.json"
        ]
        mounts = [
          {
            type     = "tmpfs"
            target   = "/tmp/csi/keys"
            readonly = false
            tmpfs_options = {
              size = 1000000 # size in bytes
            }
          }
        ]
        args = [
          "--type=cephfs",
          "--controllerserver=true",
          "--drivername=cephfs.csi.ceph.com",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}",
          "--v=5",
        ]
      }
      resources {
        cpu    = 500
        memory = 256
      }

      csi_plugin {
        id        = "cephfs-csi"
        type      = "controller"
        mount_dir = "/csi"
      }
    }
  }
}