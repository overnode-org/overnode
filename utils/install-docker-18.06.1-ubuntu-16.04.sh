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
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update

    apt-get -qq -y install --no-install-recommends docker-ce=18.06.1~ce~3-0~ubuntu

    docker --version

    # Verify that Docker Engine is installed correctly:
    docker run --rm hello-world
else
    (>&2 echo "docker is already installed")
fi
