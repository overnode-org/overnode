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

curl -X DELETE http://clusterlite-etcd:2379/v2/proxies/$1
