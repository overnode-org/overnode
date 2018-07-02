#!/usr/bin/env sh

set -e

if [ "$(which docker | wc -l)" = "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" = "1" ]
    then
        # ubuntu supports automated installation
        (>&2 echo "installing docker")
        apt-get -y update || (>&2 echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends curl
    else
        echo "Error: required: Ubuntu 16.04, found: $(lsb_release -a)" >&2
        exit 1
    fi

    # Run the installation script to get the latest docker version.
    # This is disabled in favor of controlled migration to latest docker versions
    # curl -sSL https://get.docker.com/ | sh

    # Use specific version for installation
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    mkdir -p /etc/apt/sources.list.d || true
    echo deb https://apt.dockerproject.org/repo ubuntu-xenial main > /etc/apt/sources.list.d/docker.list
    apt-get update

    apt-get -qq -y install --no-install-recommends docker-engine=17.05.0~ce-0~ubuntu-xenial

    docker --version

    # Verify that Docker Engine is installed correctly:
    docker run --rm hello-world
else
    (>&2 echo "docker is already installed")
fi
