#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# set -e :: can not set to an error, because it is expected some call are failed

# weaveid, token, volume, placement, public_ip, seeds, seed_id
data="$1,$2,$3,$4,$5,${6//,/:},$7"

green_c='\033[0;32m'
red_c='\033[0;31m'
gray_c='\033[1;30m'
no_c='\033[0m' # No Color

if [ -z "$6" ];
then
    echo -e "${red_c}[clusterlite proxy-allocate] internal error detected, proxy-allocate should be invoked with at least 6 arguments, exiting...${no_c}"
    echo -e "${red_c}[clusterlite proxy-allocate] received ${data}${no_c}"
    exit 1
fi

echo -e "${gray_c}"

curl --fail -s http://clusterlite-etcd:2379/v2/keys > /dev/null
while [ $? -ne 0 ]; do
    echo "[clusterlite proxy-allocate] waiting for clusterlite-etcd service"
    sleep 1
    curl --fail -s http://clusterlite-etcd:2379/v2/keys
done

# bootstrap storage
curl --fail -s http://clusterlite-etcd:2379/v2/keys/nodes > /dev/null
if [ $? -ne 0 ]; then
    echo "[clusterlite proxy-allocate] bootstraping clusterlite-etcd storage"
    curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes -d dir=true > /dev/null || echo ""
    curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/services -d dir=true > /dev/null  || echo ""
    curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/ips -d dir=true > /dev/null  || echo ""
    curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/credentials -d dir=true > /dev/null  || echo ""
    curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/files -d dir=true > /dev/null  || echo ""
fi

current_id=1
echo "[clusterlite proxy-allocate] scanning for the next available node id: ${current_id}"
curl --fail -s -X PUT http://clusterlite-etcd:2379/v2/keys/nodes/${current_id}?prevExist=false -d value="${data}" > /dev/null
while [ $? -ne 0 ]; do
    current_id=$((current_id+1))
    echo "[clusterlite proxy-allocate] scanning for the next available node id: ${current_id}"
    curl --fail -s -X PUT http://clusterlite-etcd:2379/v2/keys/nodes/${current_id}?prevExist=false -d value="${data}" > /dev/null
done

echo -e "${no_c}"

echo -e "${green_c}[clusterlite proxy-allocate] allocated node id: ${current_id}${no_c}"
echo ${current_id} > /data/nodeid.txt
