#!/bin/bash

#
# Webintrinsics Clusterlite:
#    Simple but powerful alternative to Kubernetes and Docker Swarm
#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#
# Prerequisites:
# - Ubuntu 16.04 machine (or another Linux with installed docker 1.13.1)
#   with valid hostname, IP interface, DNS, proxy, apt-get configuration
# - Internet connection
#

set -e

log="[clusterlite]"

run() {

#
# install docker if it does not exist
#
if [[ $(which docker || echo) == "" ]];
then
    if [[ $(uname -a | grep Ubuntu | wc -l) == "1" ]]
    then
        # ubuntu supports automated installation
        (>&2 echo "$log installing docker")
        apt-get -y update || (>&2 echo "apt-get update failed, are proxy settings correct?" && exit 1)
        apt-get -qq -y install --no-install-recommends curl
    else
        (>&2 echo "failure: docker has not been found, please install docker and run docker daemon")
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

    # Verify that Docker Engine is installed correctly:
    docker run hello-world
fi

if [[ $(docker --version) != "Docker version 1.13.1, build 092cba3" ]];
then
    (>&2 echo "failure: required docker version 1.13.1, found $(docker --version)")
    exit 1
fi

#
# Prepare the environment and command
#
(>&2 echo "$log preparing the environment")
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export HOSTNAME=$(hostname -f)
export HOSTNAME_I=$(hostname -i | awk {'print $1'})
export CLUSTERLITE_ID=$(date +%Y%m%d-%H%M%S.%N-%Z)
export IPV4_ADDRESSES=$(echo $(ifconfig | awk '/inet addr/{print substr($2,6)}') | tr " " ",")
export IPV6_ADDRESSES=$(echo $(ifconfig | awk '/inet6 addr/{print $3}') | tr " " ",")

# capture docker state
(>&2 echo "$log capturing docker state")
docker_ps=$(docker ps | grep -v CONTAINER | awk '{print $1}')
if [[ ${docker_ps} == "" ]];
then
    docker_inspect="[]"
else
    docker_inspect=$(docker inspect ${docker_ps} || echo "[]")
fi

# capture weave state
(>&2 echo "$log capturing weave state")
weave_dest=$(which weave || echo)
docker_command_net_weave=""
if [[ ${weave_dest} == "" ]];
then
    weave_inspect="{}"
else
    if [[ $(docker ps | grep weaveexec | wc -l) == "0" ]]
    then
        weave_inspect="{}"
    else
        weave_inspect=$(weave report || echo "{}")
        docker_command_net_weave="--net=weave --ip=10.32.0.100"
    fi
fi

# capture clusterlite state
(>&2 echo "$log capturing clusterlite state")
if [[ -f "/var/lib/clusterlite/volume.txt" ]];
then
    volume=$(cat /var/lib/clusterlite/volume.txt)
else
    volume=""
fi
if [[ ${volume} == "" ]];
then
    clusterlite_json="{}"
    if [ ! -d /tmp/clusterlite ]; then
        mkdir /tmp/clusterlite
    fi
    clusterlite_volume="/tmp/clusterlite"
else
    clusterlite_json=$(cat ${volume}/clusterlite.json || echo "{}")
    clusterlite_volume="${volume}/clusterlite"
fi
clusterlite_data="${clusterlite_volume}/${CLUSTERLITE_ID}"

# prepare working directory for an action
(>&2 echo "$log preparing working directory")
mkdir ${clusterlite_data}
echo ${docker_inspect} > ${clusterlite_data}/docker.json
echo ${weave_inspect} > ${clusterlite_data}/weave.json
echo ${clusterlite_json} > ${clusterlite_data}/clusterlite.json

# search for config parameter and place it to the working directory
capture_next="false"
config_path="/nonexisting/path/to/some/where"
config_regexp="^[-][-]?config[=](.*)"
for i in "$@"; do
    if [[ ${capture_next} == "true" ]]; then
        config_path=${i}
        break
    fi
    if [[ ${i} == "--config" || ${i} == "-config" ]]; then
        capture_next="true"
    fi
    if [[ ${i} =~ ${config_regexp} ]]; then
        config_path="${BASH_REMATCH[1]}"
        break
    fi
done
if [[ -f ${config_path} ]]; then
    cp ${config_path} ${clusterlite_data}/apply-config.yaml
    ls -la $(dirname ${config_path}) > ${clusterlite_data}/apply-dir.txt || echo ""
fi

#
# prepare execution command
#
(>&2 echo "$log preparing execution command")
package_dir=${SCRIPT_DIR}/target/universal
package_path=${package_dir}/clusterlite-0.1.0.zip
package_md5=${package_dir}/clusterlite.md5
package_unpacked=${package_dir}/clusterlite
if [[ -z ${package_path} ]];
then
    # production mode
    docker_command_package_volume=""
else
    # development mode
    md5_current=$(md5sum ${package_path} | awk '{print $1}')
    if [[ ! -f ${package_md5} ]] || [[ ${md5_current} != "$(cat ${package_md5})" ]] || [[ ! -d ${package_unpacked} ]]
    then
        # install unzip if it does not exist
        if [[ $(which unzip || echo) == "" ]];
        then
            if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
            then
                # ubuntu supports automated installation
                apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
                apt-get -qq -y install --no-install-recommends unzip jq
            else
                echo "failure: unzip has not been found, please install unzip utility"
                exit 1
            fi
        fi
        unzip -o ${package_path} -d ${package_dir} 1>&2
        echo ${md5_current} > ${package_md5}
    fi
    docker_command_package_volume="--volume ${package_unpacked}:/opt/clusterlite"
fi
docker_command="docker run --rm -i \
    --env HOSTNAME=$HOSTNAME \
    --env HOSTNAME_I=$HOSTNAME_I \
    --env CLUSTERLITE_ID=$CLUSTERLITE_ID \
    --env IPV4_ADDRESSES=$IPV4_ADDRESSES \
    --env IPV6_ADDRESSES=$IPV6_ADDRESSES \
    --volume ${clusterlite_volume}:/data \
    $docker_command_package_volume \
    $docker_command_net_weave \
    webintrinsics/clusterlite:0.1.0 /opt/clusterlite/bin/clusterlite $@"

#
# execute the command, capture the output and execute the output
#
(>&2 echo "$log executing ${docker_command}")
tmpscript=${clusterlite_data}/script
tmpscript_out=${clusterlite_data}/stdout.log
execute_output() {
    (>&2 echo "$log saving ${tmpscript}")
    tr -d '\015' <${tmpscript} >${tmpscript}.sh # dos2unix if needed
    first_line=$(cat ${tmpscript}.sh | head -1)
    if [[ ${first_line} == "#!/bin/bash" ]];
    then
        chmod u+x ${tmpscript}.sh
        ${tmpscript}.sh 2>&1 | tee ${tmpscript_out}
        [[ ${PIPESTATUS[0]} == "0" ]] || (>&2 echo "$log failure: internal error, please report to https://github.com/webintrinsics/clusterlite" && exit 1)
    else
        (>&2 echo "$log dry-run requested:")
        cat ${tmpscript}.sh | tee ${tmpscript_out}
    fi

    if [[ -f ${tmpscript}.sh ]]; # can be deleted as a part of uninstall action
    then
        rm ${tmpscript}.sh
    fi

    if [[ ${volume} == "" && -f "/var/lib/clusterlite/volume.txt" ]];
    then
        # volume directory has been installed, save installation logs
        volume=$(cat /var/lib/clusterlite/volume.txt)
        (>&2 echo "$log saving $volume/clusterlite/$CLUSTERLITE_ID/script")
        cp -R ${clusterlite_data} ${volume}/clusterlite
    fi
}
${docker_command} > ${tmpscript} || (execute_output && exit 1)
if [ -z ${tmpscript} ];
then
    (>&2 echo "$log exception: file ${tmpscript} has not been created")
    (>&2 echo "$log failure: internal error, please report to https://github.com/webintrinsics/clusterlite")
    exit 1
fi
execute_output
(>&2 echo "$log success: action completed")

}

run $@ # wrap in a function to prevent partial download