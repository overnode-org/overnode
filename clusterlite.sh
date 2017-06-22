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

version_system="0.2.0"
version_weave="1.9.7"
version_proxy="3.6"
version_etcd="3.1.0"

system_image="clusterlite/system:${version_system}"
weave_image="clusterlite/weave:${version_weave}"
proxy_image="clusterlite/proxy:${version_proxy}"
etcd_image="clusterlite/etcd:${version_etcd}"

debug_on="false"
for i in "$@"; do
    if [[ ${i} == "--debug" ]]; then
        debug_on="true"
        break
    fi
done

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo "$log $1")
    fi
}

launch_etcd() {
    weave_socket=$1
    volume=$2
    token=$3
    etcd_ip=$4
    etcd_seeds=$5

    echo "${log} starting etcd server"
    docker ${weave_socket} run --name clusterlite-etcd -dti --init \
        --hostname clusterlite-etcd.clusterlite.local \
        --env WEAVE_CIDR=${etcd_ip}/12 \
        --env CONTAINER_IP=${etcd_ip} \
        --env CONTAINER_NAME=clusterlite-etcd \
        --env SERVICE_NAME=clusterlite-etcd.clusterlite.local \
        --env CLUSTERLITE_TOKEN=${token} \
        --volume ${volume}/clusterlite-etcd:/data \
        --restart always \
        ${etcd_image} /run-etcd.sh ${etcd_seeds//[,]/ }
}

install() {
    seed_id=$1
    seeds=$2
    etcd_ip=$3
    etcd_seeds=$4
    volume=$5
    token=$6
    placement=$7
    public_ip=$8

    if [[ ${seed_id} == "-" ]]; then
        seed_id=""
    fi
    if [[ ${seeds} == "-" ]]; then
        seeds=""
    fi
    if [[ ${etcd_ip} == "-" ]]; then
        etcd_ip=""
    fi
    if [[ ${etcd_seeds} == "-" ]]; then
        etcd_seeds=""
    fi
    if [[ ${volume} == "-" ]]; then
        volume=""
    fi
    if [[ ${token} == "-" ]]; then
        token=""
    fi
    if [[ ${placement} == "-" ]]; then
        placement=""
    fi
    if [[ ${public_ip} == "-" ]]; then
        public_ip=""
    fi

    echo "${log} installing:"
    echo "${log} seed_id    => ${seed_id}"
    echo "${log} seeds      => ${seeds}"
    echo "${log} etcd_ip    => ${etcd_ip}"
    echo "${log} etcd_seeds => ${etcd_seeds}"
    echo "${log} volume     => ${volume}"
    echo "${log} token      => ${token}"
    echo "${log} placement  => ${placement}"
    echo "${log} public_ip  => ${public_ip}"

    weave_seed_name=""
    if [[ ${seed_id} != "" ]]; then
        weave_seed_name="--name ::${seed_id}"
    fi

    echo "${log} downloading clusterlite images"
    docker pull ${weave_image}
    docker pull ${proxy_image}
    docker pull ${etcd_image}

    echo "${log} extracting weave script"
    docker_location="$(which docker)"
    weave_location="${docker_location/docker/weave}"
    docker run --rm -i ${weave_image} > ${weave_location}
    chmod u+x ${weave_location}

    echo "${log} downloading weave images"
    #${weave_location} setup

    echo "${log} installing data directory"
    mkdir /var/lib/clusterlite || echo ""
    echo ${volume} > /var/lib/clusterlite/volume.txt
    echo ${seed_id} > /var/lib/clusterlite/seedid.txt
    echo "" > /var/lib/clusterlite/nodeid.txt
    mkdir ${volume} || echo ""
    mkdir ${volume}/clusterlite || echo ""

    echo "${log} installing weave network"
    export CHECKPOINT_DISABLE=1 # disabling weave check for new versions
    # launching weave node for uniform dynamic cluster with encryption is enabled
    # see https://www.weave.works/docs/net/latest/operational-guide/uniform-dynamic-cluster/
    # automated range allocation does not require seeds to reach a consensus
    # because the range is split in advance by seeds enumeration
    # see https://github.com/weaveworks/weave/blob/master/site/ipam.md#via-seed
    ${weave_location} launch-router --password ${token} \
        --dns-domain="clusterlite.local." \
        --ipalloc-range 10.47.255.0/24 --ipalloc-default-subnet 10.32.0.0/12 \
        ${weave_seed_name} --ipalloc-init seed=::1,::2,::3 ${seeds}
    # integrate with docker using weave proxy, it is more reliable than weave plugin
    ${weave_location} launch-proxy --rewrite-inspect

    weave_socket=$(${weave_location} config)
    if [[ ${seed_id} == "1" ]]; then
        launch_etcd ${weave_socket} ${volume} ${token} ${etcd_ip} ${etcd_seeds}
    fi

    echo "${log} allocating node id"
    weave_name=$(${weave_location} status | grep Name | awk '{print $2}')
    docker ${weave_socket} run --name clusterlite-bootstrap -ti --rm --init \
        --hostname clusterlite-bootstrap.clusterlite.local \
        --env CONTAINER_NAME=clusterlite-bootstrap \
        --env SERVICE_NAME=clusterlite-bootstrap.clusterlite.local \
        --volume /var/lib/clusterlite/nodeid.txt:/data/nodeid.txt \
        ${proxy_image} /run-proxy-allocate.sh "${weave_name}" \
            "${token}" "${volume}" "${placement}" "${public_ip}" "${seeds}" "${seed_id}"

    echo "${log} starting docker proxy"
    proxy_ip="10.47.240.$(cat /var/lib/clusterlite/nodeid.txt)" # TODO span the range to the second byte up to 10.47.255.0/24, prevent overflow
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}
    docker ${weave_socket} run --name clusterlite-proxy -dti --init \
        --hostname clusterlite-proxy.clusterlite.local \
        --env WEAVE_CIDR=${proxy_ip}/12 \
        --env CONTAINER_NAME=clusterlite-proxy \
        --env SERVICE_NAME=clusterlite-proxy.clusterlite.local \
        --volume ${weave_run}:/var/run/weave:ro \
        --volume ${volume}:/data \
        --restart always \
        ${proxy_image} /run-proxy.sh

    if [[ ${seed_id} != "1" ]]; then
        launch_etcd ${weave_socket} ${volume} ${token} ${etcd_ip} ${etcd_seeds}
    fi
}

uninstall() {
    node_id=$1
    seed_id=$2
    volume=$3

    echo "${log} stopping proxy server"
    docker exec -it clusterlite-proxy /run-proxy-remove.sh ${node_id} || \
        echo "${log} warning: failure to detach the node"
    docker stop clusterlite-proxy || \
        echo "${log} warning: failure to stop clusterlite-proxy container"
    docker rm clusterlite-proxy || \
        echo "${log} warning: failure to remove clusterlite-proxy container"

    if [[ ${seed_id} != "" ]]; then
        echo "${log} stopping etcd server"
        docker exec -it clusterlite-etcd /run-etcd-remove.sh || \
            echo "${log} warning: failure to detach clusterlite-etcd server"
        docker stop clusterlite-etcd || \
            echo "${log} warning: failure to stop clusterlite-etcd container"
        docker rm clusterlite-etcd || \
            echo "${log} warning: failure to remove clusterlite-etcd container"
        rm -Rf ${volume}/clusterlite-etcd || \
            echo "${log} warning: failure to remove ${volume}/clusterlite-etcd data"
    fi

    echo "${log} uninstalling weave network"
    docker_location="$(which docker)"
    weave_location="${docker_location/docker/weave}"
    # see https://www.weave.works/docs/net/latest/ipam/stop-remove-peers-ipam/
    ${weave_location} reset || echo "${log} warning: failure to reset weave network"

    echo "${log} uninstalling data directory"
    rm -Rf ${volume} || echo "${log} warning: ${volume} has not been removed"
    rm -Rf /var/lib/clusterlite || echo "${log} warning: /var/lib/clusterlite has not been removed"
}

run() {

if [[ $(which docker | wc -l) == "0" ]]
then
    (>&2 echo "$log failure: requires: docker, found: none")
    exit 1
fi

#
# Prepare the environment and command
#
debug "preparing the environment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOSTNAME_F=$(hostname -f)
HOSTNAME_I=$(hostname -i | awk {'print $1'})
CLUSTERLITE_ID=$(date +%Y%m%d-%H%M%S.%N-%Z)
IPV4_ADDRESSES=$(echo $(ifconfig | awk '/inet addr/{print substr($2,6)}') | tr " " ",")
IPV6_ADDRESSES=$(echo $(ifconfig | awk '/inet6 addr/{print $3}') | tr " " ",")

# capture weave state
debug "capturing weave state"
docker_location="$(which docker)"
weave_location="${docker_location/docker/weave}"
weave_config=""
if [[ -f ${weave_location} ]]; then
    if [[ $(docker ps | grep weave | wc -l) != "0" ]]; then
        weave_config=$(${weave_location} config)
    fi
fi

# capture clusterlite state
debug "$log capturing clusterlite state"
if [[ -f "/var/lib/clusterlite/volume.txt" ]];
then
    volume=$(cat /var/lib/clusterlite/volume.txt)
else
    volume=""
fi
if [[ -f "/var/lib/clusterlite/nodeid.txt" ]];
then
    node_id=$(cat /var/lib/clusterlite/nodeid.txt)
else
    node_id=""
fi
if [[ -f "/var/lib/clusterlite/seedid.txt" ]];
then
    seed_id=$(cat /var/lib/clusterlite/seedid.txt)
else
    seed_id=""
fi
if [[ ${volume} == "" ]];
then
    if [ ! -d /tmp/clusterlite ]; then
        mkdir /tmp/clusterlite
    fi
    clusterlite_volume="/tmp/clusterlite"
else
    clusterlite_volume="${volume}/clusterlite"
fi
clusterlite_data="${clusterlite_volume}/${CLUSTERLITE_ID}"

# prepare working directory for an action
debug "preparing working directory"
mkdir ${clusterlite_data}

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
fi

#
# prepare execution command
#
debug "$log preparing execution command"
package_dir=${SCRIPT_DIR}/target/universal
package_path=${package_dir}/clusterlite-${version_system}.zip
package_md5=${package_dir}/clusterlite.md5
package_unpacked=${package_dir}/clusterlite
if [[ ! -f ${package_path} ]];
then
    # production mode
    debug "$log production mode"
    docker_command_package_volume=""
else
    # development mode
    debug "development mode"
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
docker_command="docker ${weave_config} run --rm -i \
    --env HOSTNAME_F=$HOSTNAME_F \
    --env HOSTNAME_I=$HOSTNAME_I \
    --env CLUSTERLITE_ID=$CLUSTERLITE_ID \
    --env CLUSTERLITE_NODE_ID=${node_id} \
    --env CLUSTERLITE_VOLUME=${volume} \
    --env CLUSTERLITE_SEED_ID=${seed_id} \
    --env IPV4_ADDRESSES=$IPV4_ADDRESSES \
    --env IPV6_ADDRESSES=$IPV6_ADDRESSES \
    --volume ${clusterlite_volume}:/data \
    $docker_command_package_volume \
    ${system_image} /opt/clusterlite/bin/clusterlite $@"

#
# execute the command
#
debug "executing ${docker_command}"
log_out=${clusterlite_data}/stdout.log
if [[ $1 == "install" || $1 == "uninstall" ]]; then
    for i in "$@"; do
        if [[ ${i} == "--help" || ${i} == "-h" ]]; then
            ${docker_command} | tee ${log_out}
            [[ ${PIPESTATUS[0]} == "0" ]] || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        fi
    done

    if [[ $1 == "install" ]]; then
        echo "${log} downloading clusterlite system image"
        docker pull ${system_image}

        tmp_out=${clusterlite_data}/tmpout.log
        ${docker_command} > ${tmp_out} || (debug "failure: action aborted" && exit 1)
        install $(cat ${tmp_out})

        if [[ ${volume} == "" && -f "/var/lib/clusterlite/volume.txt" ]];
        then
            # volume directory has been installed, save installation logs
            volume=$(cat /var/lib/clusterlite/volume.txt)
            debug "saving $volume/clusterlite/$CLUSTERLITE_ID"
            cp -R ${clusterlite_data} ${volume}/clusterlite
        fi
    else
        tmp_out=${clusterlite_data}/tmpout.log
        ${docker_command} > ${tmp_out} || (debug "failure: action aborted" && exit 1)
        uninstall ${node_id} ${seed_id} ${volume}
    fi
else
    ${docker_command} | tee ${log_out}
    [[ ${PIPESTATUS[0]} == "0" ]] || (debug "failure: action aborted" && exit 1)
fi

debug "success: action completed" && exit 0
}

run $@ # wrap in a function to prevent partial download