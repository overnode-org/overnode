#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

while [ ! -z $1 ]; do
    service_name=$1
    shift
    file_reference=$2
    shift
    file_name=$3
    shift
    echo "[clusterlite proxy-fetch] downloading ${file_reference} => ${service_name}/${file_name}"

    curl --fail -s http://clusterlite-etcd:2379/v2/keys/files/${file_reference} | jq -j -e ".node.value" > /data/${file_name}
    [[ ${PIPESTATUS[0]} -eq "0" && $? -eq "0" ]] || \
        (curl http://clusterlite-etcd:2379/v2/keys/files/${file_reference} >&2; \
         echo "[clusterlite proxy-fetch] failure to fetch http://clusterlite-etcd:2379/v2/keys/files/${file_reference}" >&2; \
         exit 1)
done

echo "[clusterlite proxy-fetch] success: action completed"

