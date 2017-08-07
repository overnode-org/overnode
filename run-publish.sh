#!/usr/bin/env sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Prerequisites:
# - Ubuntu 16.04 machine (or another Linux with installed docker 1.13.1)
#   with valid hostname, IP interface, DNS, proxy, apt-get configuration
# - Internet connection

set -e

DIR="$( cd "$( dirname "$0" )" && pwd )" # get current file directory

${DIR}/run-package.sh

server_version=$(head -20 ${DIR}/version.sbt | grep version | awk '{print $5}' | sed -e "s/\"//" | sed -e "s/\".*//")
echo ${server_version} > ${DIR}/cluster/src/server/files/version.txt
docker build -t webintrinsics/server:${server_version} ${DIR}/cluster/src/server

if [ ! -z $1 ];
then
    # ensure docker hub credetials
    if [ "$(cat ~/.docker/config.json | grep auth\" | wc -l)" -eq "0" ]
    then
      docker login
    fi

    docker push webintrinsics/server:${server_version}
else
    echo "skipping docker push, because the script was invoked without arguments"
fi
