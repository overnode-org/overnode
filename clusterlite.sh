#!/bin/bash

#
# Webintrinsics Clusterlite - Simpler alternative to Kubernetes and Docker Swarm
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#
# Prerequisites:
# - Ubuntu 16.04 machine (or another Linux with installed docker 1.13.1)
#   with valid hostname, IP interface, DNS, proxy, apt-get configuration
# - Internet connection
#

set -e

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
    dockerd daemon -H unix:///var/run/docker.sock

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

if [[ $(docker --version) != "Docker version 1.13.1, build 092cba3" ]];
then
    echo "Required docker version 1.13.1" && exit 1;
fi

id=$(date +%Y%m%d-%H%M%S.%N-%Z)
command="docker run -ti \
--env HOSTNAME=$(hostname -f) \
--env HOSTNAME_I=$(hostname -i | awk {'print $1'}) \
--env CLUSTERLITE_ID=$id \
webintrinsics/clusterlite:0.1.0 /opt/clusterlite/bin/clusterlite $@"

# if help paramter is spotted, print the output and exit
helpRequested="false"
for i in "$@" ; do
    if [[ "${i}" == "--help" ]]
    then
        ${command}
        exit $?
    fi
done
if [[ "$1" == "-help" || "$1" == "help" || "$1" == "-h" ]]
then
    ${command}
    exit $?
fi

# otherwise, exit the command, capture the output and execute it
tmpscript=/tmp/clusterlite-cmd-${id}
${command} > ${tmpscript} || ( cat ${tmpscript} && exit 1 )
if [ -z ${tmpscript} ];
then
    echo "exception: file ${tmpscript} has not been created"
    echo "failure: internal error, please report a bug to https://github.com/webintrinsics/clusterlite"
    exit 1
fi
tr -d '\015' <${tmpscript} >${tmpscript}.sh # dos2unix if needed
rm ${tmpscript}
chmod u+x ${tmpscript}.sh
${tmpscript}.sh
rm ${tmpscript}.sh
