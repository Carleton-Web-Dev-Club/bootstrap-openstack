#sudo ceph fs authorize cephfs client.waypoint /waypoint rw

id = "wikimedia-data"
name = "wikimedia-data"
type = "csi"
plugin_id = "cephfs-csi"
capacity_max = "10G"
capacity_min = "1M"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "ext4"
  mount_flags = ["noatime"]
}

secrets {
  userID  = "wikimedia-data"
  userKey = "AQBCPOZh/DyFIxAARxH4+E13F2d6z4P+Un26Xg=="
}

parameters {
  clusterID = "ab0a7bf8-c0f0-49a1-a0c7-c8e44d83b3c7"
  fsName = "cephfs"
}

context {
  monitors = "192.168.25.137,192.168.25.159,192.168.25.253"
  provisionVolume = "false"
  rootPath = "/wikimedia/data"
  mounter = "fuse"
}
