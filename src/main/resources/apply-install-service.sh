    echo "__LOG__ __SERVICE_NAME__: installing"
__VOLUME_CREATE_PART__
__DOCKER_LOAD_OR_PULL_PART__
    echo "__LOG__ __SERVICE_NAME__: creating container"
    docker create --name __CONTAINER_NAME__ -h __SERVICE_NAME__.clusterlite.local -dti \
        --net=weave --dns=__DNS_ADDRESS__ --dns-search=__DNS_DOMAIN__ \
        --env WEAVE_CIDR=__CONTAINER_IP__/13 \
        --env CONTAINER_IP=__CONTAINER_IP__ \
        --env CONTAINER_NAME=__CONTAINER_NAME__ \
        --env SERVICE_NAME=__SERVICE_NAME__.clusterlite.local \
        --env PUBLIC_HOST_IP=__PUBLIC_HOST_IP__ \
__ENV_DEPENDENCIES____ENV_CUSTOM____VOLUME_CUSTOM____VOLUME_MOUNT_PART__        --restart always \
        __OPTIONS____IMAGE____COMMAND____ARGUMENTS__
    echo "__LOG__ __SERVICE_NAME__: starting container"
    docker start __CONTAINER_NAME__