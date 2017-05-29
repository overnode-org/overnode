#!/bin/bash

#
# Generated by Webintrinsics Clusterlite:
# __COMMAND__
#
# Parameters: __PARSED_ARGUMENTS__
#
# Prerequisites:
# - Docker engine
# - Internet connection
#

set -e

install_volume() {
    echo "__LOG__ installing data directory"
    mkdir /var/lib/clusterlite || echo ""
    echo __VOLUME__ > /var/lib/clusterlite/volume.txt

    mkdir __VOLUME__ || echo ""
    echo __CONFIG__ > __VOLUME__/clusterlite.json
}

install_weave() {
    echo "__LOG__ installing weave network"
    docker_location="$(which docker)"
    weave_destination="${docker_location/docker/weave}"
    curl -L git.io/weave -o ${weave_destination}
    chmod a+x ${weave_destination}

    export CHECKPOINT_DISABLE=1
    export WEAVE_VERSION=1.9.5
    # launching weave node with encryption and fixed set of seeds
    weave launch --password __TOKEN__ __SEEDS__
}

install_volume
install_weave
echo "__LOG__ successfully completed"
