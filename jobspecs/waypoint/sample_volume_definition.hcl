
id = "waypoint-data"
name = "waypoint-data"
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

  #sudo ceph fs authorize cephfs client.waypoint /waypoint rw
  userKey = "** **"
}

parameters {

  #sudo ceph fsid
  clusterID = "** **"
  
  fsName = "cephfs"
}

context {
  #IP Addr of you monitors
  monitors = "0.0.0.0,1.1.1.1"
  provisionVolume = "false"
  rootPath = "/waypoint"
  mounter = "fuse"
}
