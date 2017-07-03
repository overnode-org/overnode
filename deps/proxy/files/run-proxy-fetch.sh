#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

error_and_exit() {
    file_reference=$1
    curl http://clusterlite-etcd:2379/v2/keys/files/${file_reference} >&2
    echo "[clusterlite proxy-fetch] failure to fetch http://clusterlite-etcd:2379/v2/keys/files/${file_reference}" >&2
    exit 1
}

while [ ! -z $1 ]; do
    service_name=$1
    shift
    file_reference=$1
    shift
    file_name=$1
    shift
    echo "[clusterlite proxy-fetch] downloading ${file_reference} => ${service_name}/${file_name}"

    curl --fail -s http://clusterlite-etcd:2379/v2/keys/files/${file_reference} | jq -j -e ".node.value" > /data/${file_name}
    jq_code=$?

    if [ ${jq_code} -ne "0" ];then
        error_and_exit ${file_reference}
    fi
done

echo "[clusterlite proxy-fetch] success: action completed"

