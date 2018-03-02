#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

if [ -z "$1" ];
then
    echo "[cade proxy] internal error detected, proxy should be invoked with an argument, exiting..." >&2
    exit 1
fi

curl --fail -s -X DELETE http://cade-etcd:2379/v2/keys/nodes/$1.json > /dev/null || true
curl --fail -sS -X DELETE http://cade-etcd:2379/v2/keys/nodes/$1 > /dev/null

