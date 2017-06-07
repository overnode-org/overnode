
    echo "__LOG__ starting etcd server"
    docker run --name clusterlite-etcd -dti --init \
        --cidfile __VOLUME__/clusterlite-etcd.cid \
        --hostname clusterlite-etcd.clusterlite.local \
        $(weave dns-args) \
        --ip=__CONTAINER_IP__ --net=weave \
        --env CONTAINER_IP=__CONTAINER_IP__ \
        --env CONTAINER_NAME=clusterlite-etcd \
        --env SERVICE_NAME=clusterlite-etcd.clusterlite.local \
        --env CLUSTERLITE_TOKEN=__TOKEN__ \
        --volume __VOLUME__/clusterlite-etcd:/data \
        --restart always \
        webintrinsics/clusterlite-etcd:0.1.0 \
            /run-etcd.sh __ETCD_PEERS__
        # TODO investigate a bug why container is not restarted after reboot

