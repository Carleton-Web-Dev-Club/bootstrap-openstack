#ceph auth get-or-create client.nomad mon 'profile rbd' osd 'profile rbd pool=nomad' mgr 'profile rbd pool=nomad'
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
  userKey = "AQABG25hPuuEHBAAiIEEEgM5GW3q4vXDrWVsJw=="
}

parameters {
  clusterID = "ab0a7bf8-c0f0-49a1-a0c7-c8e44d83b3c7"
  pool = "nomad"
  imageFeatures = "layering"
}
