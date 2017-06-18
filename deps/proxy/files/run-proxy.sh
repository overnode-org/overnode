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

curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/proxies -d dir=true || echo ""
curl --fail -XPUT http://clusterlite-etcd:2379/v2/keys/proxies/$1 -d value="$(hostname -i)"

socat TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/docker.sock
