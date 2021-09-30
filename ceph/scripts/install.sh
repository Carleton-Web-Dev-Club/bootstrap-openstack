#!/bin/bash
cd ../deployment
ceph-deploy purgedata nc-1 nc-2 ns-1 ns-2 ns-3 backup localhost
ceph-deploy forgetkeys
rm ceph.*
ceph-deploy new ns-1 ns-2 ns-3
cat ../config/appended.conf >> ceph.conf
ceph-deploy --overwrite-conf install nc-1 nc-2 ns-1 ns-2 ns-3 backup
ceph-deploy --overwrite-conf mon create-initial
ceph-deploy --overwrite-conf admin ns-1 localhost backup nc-2 nc-1
ceph-deploy --overwrite-conf mgr create ns-1 ns-2
echo "Adding OSDs"
sudo ceph status
sleep 5
ceph-deploy disk zap backup /dev/vdb
ceph-deploy disk zap nc-1  /dev/vg-ceph/lv01
ceph-deploy disk zap nc-2  /dev/vg-ceph/lv01

ceph-deploy osd create backup --data /dev/vdb
ceph-deploy osd create nc-1 --data /dev/vg-ceph/lv01
ceph-deploy osd create nc-2 --data /dev/vg-ceph/lv01
sleep 5
sudo ceph status