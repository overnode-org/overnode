#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Prerequisites:
# - build-machine.sh has been executed
# - build-package.sh has been executed
# - internet connection

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory

#
# install docker if it does not exist
#
if [[ $(which docker) == "" ]];
then
    if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
    then
        # ubuntu supports automated installation
        apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends curl
    else
        echo "failure: docker has not been found, please install docker and run docker daemon"
        exit 1
    fi

    # Run the installation script to get the latest docker version.
    # This is disabled in favor of controlled migration to latest docker versions
    # curl -sSL https://get.docker.com/ | sh

    # Use specific version for installation
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    mkdir -p /etc/apt/sources.list.d || echo ""
    echo deb https://apt.dockerproject.org/repo ubuntu-xenial main > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get -qq -y install --no-install-recommends docker-engine=1.13.1-0~ubuntu-xenial

    # Configure and start Engine
    #dockerd daemon -H unix:///var/run/docker.sock

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

unzip -o ${DIR}/target/universal/clusterlite-0.1.0.zip -d ${DIR}/target/universal/

version=0.1.0
# build container
docker build -t webintrinsics/clusterlite:${version} ${DIR}

if [[ $1 == "--push" ]];
then
    #docker tag webintrinsics/clusterlite:${version} webintrinsics/clusterlite:${version}
    docker push webintrinsics/clusterlite:${version}
fi
