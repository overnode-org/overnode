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
if [[ $(which docker || echo) == "" ]];
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

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

#
# install unzip if it does not exist
#
if [[ $(which unzip || echo) == "" ]];
then
    if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
    then
        # ubuntu supports automated installation
        apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends unzip
    else
        echo "failure: unzip has not been found, please install unzip utility"
        exit 1
    fi
fi

docker_login() {
    credentials=".dockerhub-login"
    if [ ! -f ${DIR}/${credentials} ]; then
        echo "[docker-login] create a file ${DIR}/${credentials} with a line: --username <your-dockerhub-username> --password <your-dockerhub-password>"
        exit 1
    fi
    docker login $(cat ${DIR}/${credentials}) || (echo "[docker-login] 'docker login' failed, make sure username and password are correct in the ${credentials} file" && exit 1)
}

unzip -o ${DIR}/target/universal/clusterlite-0.1.0.zip -d ${DIR}/target/universal/

version=0.1.0
docker build -t webintrinsics/clusterlite:${version} ${DIR}

etcd_version=3.1.0
docker build -t webintrinsics/clusterlite-etcd:${etcd_version} ${DIR}/etcd

weave_version=1.9.7
docker build -t webintrinsics/clusterlite-weave:${weave_version} ${DIR}/weave

if [[ $1 == "--push" ]];
then
    docker_login
    docker push webintrinsics/clusterlite:${version}
    docker push webintrinsics/clusterlite-etcd:${etcd_version}
    docker push webintrinsics/clusterlite-weave:${weave_version}
fi
