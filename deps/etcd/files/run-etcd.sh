#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

existing_members="$@"
existing_members_number="$#"

delay_on_exit() {
    if [ -f /data/.clusterlite.removing ];
    then
        # wait a little bit to let the run-etcd-remove script to exit successfully
        sleep 60
    fi
    exit 1
}

run() {
    cmd=$1
    echo "[clusterlite etcd] executing: ${cmd}"
    ${cmd}
}

start_etcd() {
    echo "[clusterlite etcd] starting etcd cluster member on ${CONTAINER_IP}"
    current_id=1
    initial_cluster=""
    for arg in ${existing_members}
    do
        initial_cluster="clusterlite-etcd-${current_id}=http://${arg}:2380,${initial_cluster}"
        current_id=$((current_id+1))
    done
    initial_cluster="clusterlite-etcd-${current_id}=http://${CONTAINER_IP}:2380,${initial_cluster}"
    run "etcd --name clusterlite-etcd-${current_id} --data-dir=/data \
        --listen-peer-urls http://${CONTAINER_IP}:2380 \
        --listen-client-urls http://${CONTAINER_IP}:2379,http://127.0.0.1:2379 \
        --advertise-client-urls http://${CONTAINER_IP}:2379 \
        --initial-advertise-peer-urls http://${CONTAINER_IP}:2380 \
        --initial-cluster-token ${CLUSTERLITE_TOKEN} \
        --initial-cluster ${initial_cluster} \
        --initial-cluster-state existing"
}

init_and_start_etcd() {
    echo "[clusterlite etcd] initializing etcd cluster on ${CONTAINER_IP}"
    echo "[clusterlite etcd] starting etcd cluster member on ${CONTAINER_IP}"
    run "etcd --name clusterlite-etcd-1 --data-dir=/data \
        --listen-peer-urls http://${CONTAINER_IP}:2380 \
        --listen-client-urls http://${CONTAINER_IP}:2379,http://127.0.0.1:2379 \
        --advertise-client-urls http://${CONTAINER_IP}:2379 \
        --initial-advertise-peer-urls http://${CONTAINER_IP}:2380 \
        --initial-cluster-token ${CLUSTERLITE_TOKEN} \
        --initial-cluster clusterlite-etcd-1=http://${CONTAINER_IP}:2380 \
        --initial-cluster-state new"
    # the above command populates the /data directory, so this branch is executed only once
}

join_and_start_etcd() {
    echo "[clusterlite etcd] joining etcd cluster on ${CONTAINER_IP}"
    current_id=1
    endpoints=""
    for arg in ${existing_members}
    do
        endpoints="http://${arg}:2379,${endpoints}"
        current_id=$((current_id+1))
    done

    member_list_command="etcdctl --endpoints=${endpoints} member list"
    run "${member_list_command}"
    found_member=$(${member_list_command} | grep peerURLs=http://${CONTAINER_IP}:2380 | wc -l)
    if [[ ${found_member} == "0" ]]; then
        # make sure that expected existing members have joined the cluster
        # before adding itself as a member
        current_members=$(${member_list_command} | wc -l)
        while [ ${current_members} -ne ${existing_members_number} ]; do
            echo "[clusterlite etcd] waiting for ${existing_members} etcd members to form the cluster"
            sleep 5
            current_members=$(${member_list_command} | wc -l)
        done

        # add itself as a member
        run "etcdctl --endpoints=${endpoints} member add clusterlite-etcd-${current_id} http://${CONTAINER_IP}:2380"
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
