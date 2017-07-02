#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

green_c='\033[0;32m'
red_c='\033[0;31m'
gray_c='\033[1;30m'
no_c='\033[0m' # No Color

members_count=$(etcdctl member list | wc -l)
if [[ ${members_count} != 1 ]];
then
    # this file is being checked by run-etcd script
    # if it is present it does not exit and sleeps forever until stopped
    # this technique allows this script to exit successfully
    # because the container is not terminated unexpectedly due to removed etcd member
    touch /data/.clusterlite.removing
    etcd_id=$(etcdctl member list | grep clientURLs=http://${CONTAINER_IP}:2379 | awk '{print $1}')
    etcd_member=${etcd_id/:/}
    cmd="etcdctl member remove ${etcd_member}"
    echo -e "${gray_c}[clusterlite etcd] $cmd${no_c}"
    ${cmd}
else
    echo -e "${gray_c}[clusterlite etcd] ${CONTAINER_IP} is the last etcd cluster member${no_c}"
    # do nothing, when it is stopped and removed it is gone
fi
