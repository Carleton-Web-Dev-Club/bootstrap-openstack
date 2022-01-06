job "cephfs-csi-plugin-nodes" {
  datacenters = ["cwdc"]
  type        = "system"
  group "nodes" {
    network {
      port "metrics" {}
    }
    task "ceph-node" {
      driver = "docker"
      config {
        image = "quay.io/cephcsi/cephcsi:v3.4.0"
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
          "--drivername=cephfs.csi.ceph.com",
          "--nodeserver=true",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}-fs",
          "--v=5",        ]
        privileged = true
      }
      resources {
        cpu    = 500
        memory = 256
      }
      csi_plugin {
        id        = "cephfs-csi"
        type      = "node"
        mount_dir = "/csi"
      }
    }
  }
}