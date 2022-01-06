#sudo ceph fs authorize cephfs client.waypoint / rw

id = "test-volume"
name = "test-volume"
type = "csi"
plugin_id = "cephfs-csi"
capacity_max = "1G"
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
  userID  = "waypoint"
  #CHANGE
  userKey = "** **"
}

parameters {
  #CHANGE
  clusterID = "** **"
  fsName = "cephfs"
}

context {
  #CHANGE
  monitors = "** **"
  provisionVolume = "false"
  rootPath = "/"
  mounter = "fuse"
}
