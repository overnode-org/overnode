#!/usr/bin/env sh

# Dependencies:
# - ubuntu 16.04
#   valid hostname, IP interface, DNS, proxy, apt-get configuration
# - internet connection

set -e

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

if [ "$(id -u)" -ne "0" ]
then
    echo "Error: root privileges required"
    echo "Try running with 'sudo <command>'"
    exit 1
fi

if [ "$(which java | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" -eq "1" ]
    then
        # ubuntu supports automated installation
        (>&2 echo "installing java")
        apt-get -y update || (>&2 echo "apt-get update failed, are proxy settings correct?" && exit 1)
    else
        echo "Error: required: Ubuntu 16.04, found: $(lsb_release -a)" >&2
        exit 1
    fi

    apt-get update
    JRE_VERSION=8u131-b11-0ubuntu1.16.04.2
    apt-get -qq -y install --no-install-recommends openjdk-8-jre-headless=${JRE_VERSION}
fi

if [ "$(which sbt | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" -eq "1" ]
    then
        # ubuntu supports automated installation
        (>&2 echo "installing npm")
        apt-get -y update || (>&2 echo "apt-get update failed, are proxy settings correct?" && exit 1)
    else
        echo "Error: required: Ubuntu 16.04, found: $(lsb_release -a)" >&2
        exit 1
    fi

    echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823
    apt-get update
    apt-get install sbt
fi

#
# install docker if it does not exist
#
if [ "$(which docker | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" -eq "1" ]
    then
        # ubuntu supports automated installation
        apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends curl
    else
        echo "Error: docker has not been found, please install docker and run docker daemon" >&2
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
    apt-get -qq -y install --no-install-recommends docker-engine
fi

#
# install unzip if it does not exist
#
if [ "$(which unzip | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" -eq "1" ]
    then
        # ubuntu supports automated installation
        apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends unzip
    else
        echo "Error: unzip has not been found, please install unzip utility" >&2
        exit 1
    fi
fi
