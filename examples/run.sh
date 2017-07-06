#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Dependencies:
# - ubuntu 16.04 or CentOs 7.1 machine with
#   valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
# - internet connection

set -e

DIR="$( cd "$( dirname "$0" )" && pwd )" # get current file directory

# install docker if it does not exists
if [ "$(which docker | wc -l)" -eq "0" ]
then
    if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
    then
        apt-get -y update
        rc=$?; if [[ ${rc} != 0 ]]; then echo "apt-get update failed (are proxy settings correct?), return code: $rc, aborting"; exit ${rc}; fi
    else
        yum -y update
        rc=$?; if [[ ${rc} != 0 ]]; then echo "yum update failed (are proxy settings correct?), return code: $rc, aborting"; exit ${rc}; fi
    fi

    # Run the installation script.
    curl -sSL https://get.docker.com/ | sh

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

vendor="clusterlite"

build_image() {
    location="$1"
    version=$(cat ${DIR}/${location}/files/version.txt || echo $2)

    echo "[build-image][started]: ${vendor}/${location}:${version}"
    docker build -t ${vendor}/${location}:${version} ${DIR}/${location}
    echo "[build-image][finished]: ${vendor}/${location}:${version} -> ${destination}"
}

save_image() {
    location="$1"
    version=$(cat ${DIR}/${location}/files/version.txt || echo $2)
    destination=${DIR}/../image-${vendor}-${location}-${version}.tar

    echo "[save-image][started]: ${vendor}/${location}:${version} -> ${destination}"
    docker save --output ${destination} ${vendor}/${location}:${version}
    echo "[save-image][finished]: ${vendor}/${location}:${version} -> ${destination}"
}

pull_image() {
    name="$1"
    version=$(cat ${DIR}/${location}/files/version.txt || echo $2)

    echo "[pull-image][started]: ${vendor}/${name}:${version}"
    docker pull ${vendor}/${name}:${version}
    echo "[pull-image][finished]: ${vendor}/${name}:${version}"
}

push_image() {
    name="$1"
    version=$(cat ${DIR}/${location}/files/version.txt || echo $2)

    # ensure docker hub credetials
    if [ "$(cat ~/.docker/config.json | grep auth\" | wc -l)" -eq "0" ]
    then
      docker login
    fi

    echo "[push-image][started]: ${vendor}/${name}:${version}"
    docker push ${vendor}/${name}:${version}
    echo "[push-image][finished]: ${vendor}/${name}:${version}"
}

source ${DIR}/tasks.sh

