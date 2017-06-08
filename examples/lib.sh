#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Dependencies:
# - ubuntu 16.04 or CentOs 7.1 machine with
#   valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
# - internet connection

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory

# install docker if it does not exists
if [[ $(which docker) == "" ]];
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

    # Configure and start Engine
    dockerd daemon -H unix:///var/run/docker.sock

    # workaround for FATA[0000] Error starting daemon: pid file found, ensure docker is not running or delete /var/run/docker.pid
    # apparently it is not fatal and a script succeeds without this wait, but let make the output clean
    #sleep 10

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

build_image() {
    vendor="$1"
    location="$2"
    version="$3"
    destination=${DIR}/../lib/image-${vendor}-${location}-${version}.tar

    echo "[build-image][started]: ${vendor}/${name}:${version} -> ${destination}"

    source=${DIR}/${location}
    find ${source} -type f -exec md5sum {} \;
    md5_current=$(find ${source} -type f -exec md5sum {} \; | sort -k 2 | awk '{print $1}' | md5sum)
    md5_file="${DIR}/.vagrant/md5-$vendor-$location.txt"

    if [ -f ${md5_file} ] && [[ $(echo ${md5_current}) == $(cat ${md5_file}) ]] && [ -f ${destination} ]
    then
        echo "[build-image] no changes detected in ${source}, skipping the build of the image"
        image_match=$(docker images | grep $location | grep $version | wc -l)
        if [ "$image_match" -eq "0" ]
        then
            echo "[build-image] loading the image to the local registry"
            docker load --input ${destination}
        fi
    else
        # TODO think about better name to track and invalidate dependencies
        if [ ${location} == "base" ]
        then
            echo "[build-image] base image has changed, all dependant images will be rebuilt too"
            rm ${DIR}/.vagrant/md5-*.txt | echo ""
        fi
        # TODO think about better name to track and invalidate dependencies
        if [ ${location} == "base-jvm" ]
        then
            echo "[build-image] base-jvm image has changed, all dependant images will be rebuilt too"
            cp ${DIR}/.vagrant/md5-webintrinsics-base.txt ${DIR}/.vagrant/md5-webintrinsics-base.txt.bak
            rm ${DIR}/.vagrant/md5-*.txt | echo ""
            cp ${DIR}/.vagrant/md5-webintrinsics-base.txt.bak ${DIR}/.vagrant/md5-webintrinsics-base.txt
        fi

        docker build -t ${vendor}/${location}:${version} ${DIR}/${location}
        echo "[build-image] saving ${vendor}/${location}:${version} image to ${destination}"
        docker save --output ${destination} ${vendor}/${location}:${version}

        echo ${md5_current} > ${md5_file}
    fi

    echo "[build-image][finished]: ${vendor}/${name}:${version} -> ${destination}"
}

pull_image() {
    vendor="$1"
    name="$2"
    version="$3"
    destination=${DIR}/../lib/image-${vendor}-${name}-${version}.tar

    echo "[pull-image][started]: ${vendor}/${name}:${version} -> ${destination}"
    if [ -f ${destination} ]
    then
        echo "[pull-image] image exists, skipping the download of the image"
        image_match=$(docker images | grep ${vendor} | grep ${name} | grep ${version} | wc -l)
        if [ "$image_match" -eq "0" ]
        then
            echo "[pull-image] loading the image to the local registry"
            docker load --input ${destination}
        fi
    else
        echo "[pull-image] image does not exist, downloading the image"
        docker pull ${vendor}/${name}:${version}
        echo "[pull-image] saving ${vendor}/${location}:${version} image to ${destination}"
        docker save --output ${destination} ${vendor}/${name}:${version}
    fi
    echo "[pull-image][finished]: ${vendor}/${name}:${version} -> ${destination}"
}

push_image() {
    vendor="$1"
    name="$2"
    version="$3"
    destination=${DIR}/../lib/image-${vendor}-${name}-${version}.tar

    echo "[push-image][started]: ${vendor}/${name}:${version} -> ${destination}"
    if [ -f ${destination} ]
    then
        echo "[push-image] image exists, skipping the build of the image"
        image_match=$(docker images | grep ${vendor} | grep ${name} | grep ${version} | wc -l)
        if [ "$image_match" -eq "0" ]
        then
            echo "[push-image] loading the image to the local registry"
            docker load --input ${destination}
        fi
        echo "[push-image] pushing the image to the dockerhub registry"
        docker tag ${vendor}/${name}:${version} ${vendor}/${name}:${version}
        docker push ${vendor}/${name}:${version} \
            || ( echo "[push-image] docker push ${vendor}/${name}:${version} failed, make sure you executed 'docker login' before or added docker_login in tasks.sh file" && exit 1 )
    else
        echo "[push-image] image does not exist, building the image"
        build_image ${vendor} ${name} ${version}
        push_image ${vendor} ${name} ${version}
    fi
    echo "[push-image][finished]: ${vendor}/${name}:${version} -> ${destination}"
}

docker_login() {
    credentials=".dockerhub-login"
    if [ ! -f ${DIR}/${credentials} ]; then
        echo "[docker-login] create a file ${DIR}/${credentials} with a line: --username <your-dockerhub-username> --password <your-dockerhub-password>"
        exit 1
    fi
    docker login $(cat ${DIR}/${credentials}) || (echo "[docker-login] 'docker login' failed, make sure username and password are correct in the ${credentials} file" && exit 1)
}