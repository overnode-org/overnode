#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Prerequisites:
# - Ubuntu 16.04 machine (or another Linux with installed docker 1.13.1)
#   with valid hostname, IP interface, DNS, proxy, apt-get configuration
# - Internet connection

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
    apt-get -qq -y install --no-install-recommends docker-engine

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

docker_login() {
    credentials=".dockerhub-login"
    if [ ! -f ${DIR}/${credentials} ]; then
        echo "[docker-login] create a file ${DIR}/${credentials} with a line: --username <your-dockerhub-username> --password <your-dockerhub-password>"
        exit 1
    fi
    docker login $(cat ${DIR}/${credentials}) || (echo "[docker-login] 'docker login' failed, make sure username and password are correct in the ${credentials} file" && exit 1)
}

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

# build system
line=$(head -20 ${DIR}/clusterlite.sh | grep version_system)
version=${line/version_system=/}
unzip -o ${DIR}/target/universal/clusterlite-${version}.zip -d ${DIR}/target/universal/
line=$(head -20 ${DIR}/clusterlite.sh | grep version_terraform)
terraform_version=${line/version_terraform=/}
if [ ! -f ${DIR}/deps/terraform-${terraform_version} ];
then
    wget -q -O /tmp/terraform_${terraform_version}_linux_amd64.zip \
        https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip
    unzip -o /tmp/terraform_${terraform_version}_linux_amd64.zip -d ${DIR}/deps/
    mv ${DIR}/deps/terraform ${DIR}/deps/terraform-${terraform_version}
fi
cp ${DIR}/deps/terraform-${terraform_version} ${DIR}/deps/terraform
docker build -t clusterlite/system:${version} ${DIR}
rm ${DIR}/deps/terraform

# build etcd
line=$(head -20 ${DIR}/clusterlite.sh | grep version_etcd)
etcd_version=${line/version_etcd=/}
echo ${etcd_version} > ${DIR}/deps/etcd/files/version.txt
docker build -t clusterlite/etcd:${etcd_version} ${DIR}/deps/etcd

# build weave
line=$(head -20 ${DIR}/clusterlite.sh | grep version_weave)
weave_version=${line/version_weave=/}
echo ${weave_version} > ${DIR}/deps/weave/files/version.txt
docker build -t clusterlite/weave:${weave_version} ${DIR}/deps/weave

# build proxy
line=$(head -20 ${DIR}/clusterlite.sh | grep version_proxy)
proxy_version=${line/version_proxy=/}
echo ${proxy_version} > ${DIR}/deps/proxy/files/version.txt
docker build -t clusterlite/proxy:${proxy_version} ${DIR}/deps/proxy

if [[ ! -z $1 ]];
then
    docker_login
    docker push clusterlite/system:${version}
    docker push clusterlite/etcd:${etcd_version}
    docker push clusterlite/weave:${weave_version}
    docker push clusterlite/proxy:${proxy_version}
else
    echo "skipping docker push, because the script was invoked without arguments"
fi
