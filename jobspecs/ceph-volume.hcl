id = "ceph-mysql"
name = "ceph-mysql"
type = "csi"
plugin_id = "ceph-csi"
capacity_max = "5G"
capacity_min = "1G"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

secrets {
  userID  = "nomad"
  userKey = "AQDHnFphHjHoNxAALCTM727rUt8Mv9OiWFQdTw=="
}

parameters {
  clusterID = "6ae1b777-17b3-43cd-bbca-33dbb0321fb6"
  pool = "nomad"
  imageFeatures = "layering"
}
