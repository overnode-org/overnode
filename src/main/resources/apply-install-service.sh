    echo "__LOG__ __SERVICE_NAME__: installing"
__VOLUME_CREATE_PART__
__DOCKER_LOAD_OR_PULL_PART__
    echo "__LOG__ __SERVICE_NAME__: launching container"
    docker __DOCKER_SOCKET__ run --name __CONTAINER_NAME__ -dti --init \
        --cidfile __VOLUME__/__CONTAINER_NAME__.cid \
        --hostname __SERVICE_NAME__.clusterlite.local \
        --dns=__WEAVE_DNS_ADDRESS__ --dns-search=__WEAVE_DNS_DOMAIN__ \
        --env WEAVE_CIDR=__CONTAINER_IP__/12 \
        --env CONTAINER_IP=__CONTAINER_IP__ \
        --env CLUSTERLITE_SIGNATURE=__CLUSTERLITE_SIGNATURE__\
        --env CONTAINER_NAME=__CONTAINER_NAME__ \
        --env SERVICE_NAME=__SERVICE_NAME__.clusterlite.local \
        --env PUBLIC_HOST_IP=__PUBLIC_HOST_IP__ \
__ENV_SERVICE_SEEDS____ENV_DEPENDENCIES____ENV_CUSTOM____VOLUME_CUSTOM____VOLUME_MOUNT_PART__        --restart always \
        __OPTIONS____IMAGE____COMMAND__
