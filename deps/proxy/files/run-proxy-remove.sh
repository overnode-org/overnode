#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

if [ -z "$1" ];
then
    echo "[clusterlite proxy] internal error detected, proxy should be invoked with an argument, exiting..."
    exit 1
fi

curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.weave
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.token
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.volume
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.placement
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.public_ip
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.seeds
curl --fail -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.seed_id

