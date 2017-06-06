#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

script_args="$@"

delay_on_exit() {
    if [ -f /data/.clusterlite.removing ];
    then
        # wait a little bit to let the run-etcd-remove script to exit successfully
        sleep 60
    fi
    exit 1
}

start_etcd() {
    echo "[clusterlite etcd] restarting etcd cluster member on ${CONTAINER_IP}"
    current_id=1
    initial_cluster=""
    for arg in ${script_args}
    do
        initial_cluster="clusterlite-etcd-${current_id}=http://${arg}:2380,${initial_cluster}"
        current_id=$((current_id+1))
    done
    initial_cluster="clusterlite-etcd-${current_id}=http://${CONTAINER_IP}:2380,${initial_cluster}"
    cmd="etcd --name clusterlite-etcd-${current_id} --data-dir=/data \
        --listen-peer-urls http://${CONTAINER_IP}:2380 \
        --listen-client-urls http://${CONTAINER_IP}:2379,http://127.0.0.1:2379 \
        --advertise-client-urls http://${CONTAINER_IP}:2379 \
        --initial-advertise-peer-urls http://${CONTAINER_IP}:2380 \
        --initial-cluster-token ${CLUSTERLITE_TOKEN} \
        --initial-cluster ${initial_cluster} \
        --initial-cluster-state existing"
    echo "[clusterlite etcd] $cmd"
    ${cmd}
}

init_and_start_etcd() {
    echo "[clusterlite etcd] initializing etcd cluster on ${CONTAINER_IP}"
    cmd="etcd --name clusterlite-etcd-1 --data-dir=/data \
        --listen-peer-urls http://${CONTAINER_IP}:2380 \
        --listen-client-urls http://${CONTAINER_IP}:2379,http://127.0.0.1:2379 \
        --advertise-client-urls http://${CONTAINER_IP}:2379 \
        --initial-advertise-peer-urls http://${CONTAINER_IP}:2380 \
        --initial-cluster-token ${CLUSTERLITE_TOKEN} \
        --initial-cluster clusterlite-etcd-1=http://${CONTAINER_IP}:2380 \
        --initial-cluster-state new"
    echo "[clusterlite etcd] $cmd"
    ${cmd}
    # the above command populates the /data directory, so this branch is executed only once
}

join_and_start_etcd() {
    echo "[clusterlite etcd] joining etcd cluster on ${CONTAINER_IP}"
    current_id=1
    endpoints=""
    for arg in ${script_args}
    do
        endpoints="http://${arg}:2379,${endpoints}"
        current_id=$((current_id+1))
    done

    cmd="etcdctl --endpoints=${endpoints} member list"
    echo "[clusterlite etcd] $cmd"
    found_member=$(${cmd} | grep peerURLs=http://${CONTAINER_IP}:2380 | wc -l)
    if [[ ${found_member} == "0" ]]; then
        cmd="etcdctl --endpoints=${endpoints} member add clusterlite-etcd-${current_id} http://${CONTAINER_IP}:2380"
        echo "[clusterlite etcd] $cmd"
        ${cmd}
    fi
    start_etcd
}


data_dir=$(ls /data)
if [ -z "$data_dir" ];
then
    if [ -z "$1" ];
    then
        init_and_start_etcd
        delay_on_exit
    else
        join_and_start_etcd
        delay_on_exit
    fi
else
    start_etcd
    delay_on_exit
fi
