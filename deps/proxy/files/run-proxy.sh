#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

if [ -z "$8" ];
then
    echo "[clusterlite proxy] internal error detected, proxy should be invoked with 8 arguments, exiting..."
    exit 1
fi

curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes -d dir=true || echo ""
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1 -d value=$(hostname -i)
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.weave -d value="$2"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.token -d value="$3"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.volume -d value="$4"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.placement -d value="$5"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.public_ip -d value="$6"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.seeds -d value="$7"
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/nodes/$1.seed_id -d value="$8"

socat TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/docker.sock
