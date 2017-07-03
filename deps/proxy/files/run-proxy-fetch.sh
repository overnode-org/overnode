#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

data_dir="/data/clusterlite-local"
if [ ! -d ${data_dir} ]; then
    mkdir ${data_dir} || true
fi

while [ ! -z $1 ]; do
    file_reference=$1
    shift
    file_edition=$1
    shift

    if [ -f ${data_dir}/${file_reference}/${file_edition} ]; then
        echo "[clusterlite proxy-fetch] already exists ${file_reference} => ${data_dir}/${file_reference}/${file_edition}"
    else
        echo "[clusterlite proxy-fetch] downloading ${file_reference} => ${data_dir}/${file_reference}/${file_edition}"

        if [ ! -d ${data_dir}/${file_reference} ]; then
            mkdir ${data_dir}/${file_reference} || true
        fi

        fetched_content=$(curl --fail -sS http://clusterlite-etcd:2379/v2/keys/files/${file_reference})
        if [ $? -ne "0" ];then
            echo "[clusterlite proxy-fetch] failure to fetch http://clusterlite-etcd:2379/v2/keys/files/${file_reference}" >&2
            exit 1
        fi

        fetched_edition="$(echo "${fetched_content}" | jq -j ".node.modifiedIndex")"
        if [ "${fetched_edition}" == "null" ];then
            echo "[clusterlite proxy-fetch] failure to parse .node.modifiedIndex JSON data:" >&2
            echo "${fetched_content}" >&2
            exit 1
        fi
        if [ "${fetched_edition}" != "${file_edition}" ];then
            # should output to stdout, because it is expected by the caller
            echo "[clusterlite proxy-fetch] failure: action aborted: newer file edition ${fetched_edition} was uploaded, expected ${file_edition}"
            exit 1
        fi

        echo "${fetched_content}" | jq -j ".node.value" > ${data_dir}/${file_reference}/${file_edition}
        if [ $? -ne "0" ];then
            echo "[clusterlite proxy-fetch] failure to parse .node.value JSON data" >&2
            echo "${fetched_content}" >&2
            exit 1
        fi
    fi
done

# should output to stdout, because it is expected by the caller
echo "[clusterlite proxy-fetch] success: action completed"

