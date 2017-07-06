#!/usr/bin/env sh

# Dependencies:
# - ubuntu 16.04
#   valid hostname, IP interface, DNS, proxy, apt-get configuration
# - internet connection

set -e

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

if [ "$(which java | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" = "1" ]
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
else
    (>&2 echo "java is already installed")
fi

if [ "$(which sbt | wc -l)" -eq "0" ]
then
    if [ "$(lsb_release -a | grep xenial | wc -l)" = "1" ]
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
else
    (>&2 echo "sbt is already installed")
fi

cd ${DIR}
sbt "universal:packageBin"
