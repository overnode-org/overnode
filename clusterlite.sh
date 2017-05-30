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

#
# Prepare the environment and command
#
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export HOSTNAME=$(hostname -f)
export HOSTNAME_I=$(hostname -i | awk {'print $1'})
export CLUSTERLITE_ID=$(date +%Y%m%d-%H%M%S.%N-%Z)

package_dir=${SCRIPT_DIR}/target/universal
package_path=${package_dir}/clusterlite-0.1.0.zip
package_md5=${package_dir}/clusterlite.md5
package_unpacked=${package_dir}/clusterlite
if [ -z ${package_path} ];
then
    # production mode
    command="docker run -ti \
    --env HOSTNAME=$HOSTNAME \
    --env HOSTNAME_I=$HOSTNAME_I \
    --env CLUSTERLITE_ID=$CLUSTERLITE_ID \
    webintrinsics/clusterlite:0.1.0 /opt/clusterlite/bin/clusterlite $@"
else
    # development mode
    md5_current=$(md5sum ${package_path} | awk '{print $1}')
    if [ ! -f ${package_md5} ] || [[ $(echo ${md5_current}) != $(cat ${package_md5}) ]] || [ ! -d ${package_unpacked} ]
    then
        unzip -o ${package_path} -d ${package_dir}
        echo ${md5_current} > ${package_md5}
    fi
    command="${package_unpacked}/bin/clusterlite $@"
fi

#
# execute the command, capture the output and execute the output
#
tmpscript=/tmp/clusterlite-cmd-${CLUSTERLITE_ID}
execute_output() {
    first_line=$(cat ${tmpscript} | head -1)
    tr -d '\015' <${tmpscript} >${tmpscript}.sh # dos2unix if needed
    rm ${tmpscript}
    if [[ ${first_line} == "#!/bin/bash" ]];
    then
        chmod u+x ${tmpscript}.sh
        ${tmpscript}.sh
    else
        cat ${tmpscript}.sh
    fi
    rm ${tmpscript}.sh
}

${command} > ${tmpscript} || ( execute_output && exit 1 )
if [ -z ${tmpscript} ];
then
    echo "exception: file ${tmpscript} has not been created"
    echo "failure: internal error, please report a bug to https://github.com/webintrinsics/clusterlite"
    exit 1
fi
execute_output
