
    echo "__LOG__ starting etcd server"
    docker $(weave config) run --name clusterlite-etcd -dti --init \
        --hostname clusterlite-etcd.clusterlite.local \
        $(weave dns-args) \
        --env WEAVE_CIDR=__CONTAINER_IP__/12 \
        --env CONTAINER_IP=__CONTAINER_IP__ \
        --env CONTAINER_NAME=clusterlite-etcd \
        --env SERVICE_NAME=clusterlite-etcd.clusterlite.local \
        --env CLUSTERLITE_TOKEN=__TOKEN__ \
        --volume __VOLUME__/clusterlite-etcd:/data \
        --restart always \
        ${etcd_image} /run-etcd.sh __ETCD_PEERS__

