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

version_system=0.4.0
version_weave=1.9.7
version_proxy=3.6
version_etcd=3.1.0
version_terraform=0.9.8
version_docker_min=1.13.0 # should be higher than weave requirement

set -e

log="[clusterlite]"

system_image="clusterlite/system:${version_system}"
weave_image="clusterlite/weave:${version_weave}"
proxy_image="clusterlite/proxy:${version_proxy}"
etcd_image="clusterlite/etcd:${version_etcd}"

debug_on="false"

docker_location="docker" # will be updated to full path later
docker_init_location="docker-init" # will be updated to full path later
weave_location="weave" # will be updated to full path later

green_c='\033[0;32m'
red_c='\033[0;31m'
gray_c='\033[1;30m'
no_c='\033[0m' # No Color

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo -e "${gray_c}$log $1${no_c}")
    fi
}

usage_no_exit() {

line="${gray_c}----------------------------------------------------------------------------${no_c}"

printf """> ${green_c}clusterlite [--debug] <action> [OPTIONS]${no_c}

  Actions / Options:
  ${line}
  ${green_c}help${no_c}      Print this help information.
  ${green_c}version${no_c}   Print version information.
  ${line}
  ${green_c}nodes${no_c}     Show information about installed nodes.
            Nodes are instances of connected to a cluster machines.
            Run 'install'/'uninstall' actions to add/remove nodes.
  ${green_c}users${no_c}     Show information about active credentials.
            Credentials are used to pull images from private repositories.
            Run 'login'/'logout' actions to add/change/remove credentials.
  ${green_c}files${no_c}     Show information about uploaded files.
            Files are used to distribute configurations/secrets to services.
            Run 'upload'/'download' actions to add/remove/view files content.
  ${green_c}services${no_c}  Show the current state of the cluster, details
            about downloaded images, created containers and services
            across all nodes of the cluster. Run 'apply'/'destroy' actions
            to change the state of the cluster.
  ${line}
  ${green_c}install${no_c}   Install clusterlite node on the current host and join the cluster.
    ${green_c}--token <cluster-wide-token>${no_c}
            Cluster-wide secret key should be the same for all joining hosts.
    ${green_c}--seeds <host1,host2,...>${no_c}
            Seed nodes store cluster-wide configuration and coordinate various
            cluster management tasks, like assignment of IP addresses.
            Seeds should be private IP addresses or valid DNS host names.
            3-5 seeds are recommended for high-availability and reliability.
            7 is the maximum to keep efficient quorum-based coordination.
            When a host joins as a seed node, it should be listed in the seeds
            parameter value and *order* of seeds should be the same on all
            joining seeds! Seed nodes can be installed in any order or
            in parallel: the second node joins when the first node is ready,
            the third joins when two other seeds form the alive quorum.
            When host joins as a regular (non seed) node, seeds parameter can
            be any subset of existing seeds listed in any order.
            Regular nodes can be launched in parallel and
            even before the seed nodes, they will join eventually.
    ${green_c}[--volume /var/lib/clusterlite]${no_c}
            Directory where stateful services will persist data. Each service
            will get it's own sub-directory within the defined volume.
    ${green_c}[--public-address <ip-address>]${no_c}
            Public IP address of the host, if it exists and requires exposure.
    ${green_c}[--placement default]${no_c}
            Role allocation for a node. A node schedules services according to
            the matching placement defined in the configuration file,
            which is set via 'apply' action.
    ${gray_c}Example: initiate the cluster with the first seed node:
      host1> clusterlite install --token abcdef0123456789 --seeds host1
    Example: add 2 other hosts as seed nodes:
      host2> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3
      host3> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3
    Example: add 1 more host as regular node:
      host4> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3${no_c}
  ${green_c}uninstall${no_c} Destroy containers scheduled on the current host,
            remove data persisted on the current host and leave the cluster.
  ${line}
  ${green_c}login${no_c}     Provide credentials to download images from private repositories.
    ${green_c}--username <username>${no_c}
            Docker registry username.
    ${green_c}--password <password>${no_c}
            Docker registry password.
    ${green_c}[--registry registry.hub.docker.com]${no_c}
            Address of docker registry to login to. If you have got multiple
            different registries, execute 'login' action multiple times.
            Credentials can be also different for different registries.
  ${green_c}logout${no_c}    Removes credentials for a registry.
    ${green_c}[--registry registry.hub.docker.com]${no_c}
            Address of docker registry to logout from. If you need to logout
            from multiple different registries, execute it multiple times
            specifying different registries each time.
  ${line}
  ${green_c}upload${no_c}    Upload new file content or delete existing.
    ${green_c}[--source </path/to/text/file>]${no_c}
            Path to a file to upload. If not specified, target parameter
            should be specified and the action will cause deletion
            of the file referred by the target parameter.
    ${green_c}--target <file-id>${no_c}
            Reference of a file to upload to or delete. If not specified,
            source parameter should be specified and target parameter
            will be set to source file name by default.
  ${green_c}download${no_c}  Print content of a file by it's reference.
    ${green_c}--target <file-id>${no_c}
            Reference of a file to print. Use 'files' action to get the list
            of available files.
  ${line}
  ${green_c}plan${no_c}      Inspect the current state of the cluster against
            the current or the specified configuration and show
            what changes the 'apply' action will provision once invoked
            with the same configuration and the same state of the cluster.
            The action is applied to all nodes of the cluster.
    ${green_c}[--config /path/to/yaml/file]${no_c}
            Cluster-wide configuration of services and placement rules.
            If it is not specified, the latest applied configuration is used.
  ${green_c}apply${no_c}     Inspect the current state of the cluster against
            the current or the specified configuration and apply
            the changes required to bring the state of the cluster
            to the state specified in the configuration. This action is
            cluster-wide operation, i.e. every node of the cluster will
            download necessary docker images and schedule running services.
    ${green_c}[--config /path/to/yaml/file]${no_c}
            Cluster-wide configuration of services and placement rules.
            If it is not specified, the latest applied configuration is used.
  ${green_c}destroy${no_c}   Terminate all running containers and services.
            The action is applied to all nodes of the cluster.
  ${line}
  ${green_c}docker${no_c}    Run docker command on one, multiple or all nodes of the cluster.
    ${green_c}[--nodes 1,2,..]${no_c}
            Comma separated list of IDs of nodes where to run the command.
            If it is not specified, the action is applied to all nodes.
    ${green_c}<docker-command> [docker-options]${no_c}
            Valid docker command and options. See docker help for details.
    ${gray_c}Example: list running containers on node #1:
      hostX> clusterlite docker ps --nodes 1
    Example: print logs for my-service container running on nodes 1 and 2:
      hostX> clusterlite docker logs my-service --nodes 1,2
    Example: print running processes in my-service container for all nodes:
      hostX> clusterlite docker exec -it --rm my-service ps -ef${no_c}
  ${line}
  ${green_c}expose${no_c}    Allow the current host to access the network of the cluster.
  ${green_c}hide${no_c}      Disallow the current host to access the network of the cluster.
  ${green_c}lookup${no_c}    Execute DNS lookup against the internal DNS of the cluster.
            The action is applied to all nodes of the cluster.
    ${green_c}<service-name>${no_c}
            Service name or container name to lookup.
  ${line}
"""
}

version_action() {
    echo -e "${green_c}Webintrinsics Clusterlite, version $version_system${no_c}"
}

docker_proxy_ip_result=""
docker_proxy_ip() {
    docker_proxy_ip_result="10.47.240.$1" # TODO span the range to the second byte up to 10.47.255.0/24, prevent overflow
}

# Given $1 and $2 as semantic version numbers like 3.1.2, return [ $1 < $2 ]
version_lt() {
    VERSION_MAJOR=${1%.*.*}
    REST=${1%.*} VERSION_MINOR=${REST#*.}
    VERSION_PATCH=${1#*.*.}

    MIN_VERSION_MAJOR=${2%.*.*}
    REST=${2%.*} MIN_VERSION_MINOR=${REST#*.}
    MIN_VERSION_PATCH=${2#*.*.}

    if [ \( "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" \) -o \
        \( "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a \
        \( "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" -o \
        \( "$VERSION_MINOR" -eq "$MIN_VERSION_MINOR" -a \
        \( "$VERSION_PATCH" -lt "$MIN_VERSION_PATCH" \) \) \) \) ] ; then
        return 0
    fi
    return 1
}

ensure_docker() {
    if [[ $(which docker | wc -l) == "0" ]]
    then
        echo -e "${red_c}$log Error: requires: docker, found: none$no_c" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi

    if ! docker_version=$(docker -v | sed -n -e 's|^Docker version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*|\1|p') || [ -z "$docker_version" ] ; then
        echo -e "${red_c}$log Error: unable to parse docker version${no_c}" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi

    if version_lt ${docker_version} ${version_docker_min} ; then
        echo -e "${red_c}${log} Error: clusterlite requires Docker version $version_docker_min or later; you are running $docker_version${no_c}" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi

    # should pass the following if the previous is passed
    if [[ $(which docker-init | wc -l) == "0" ]]
    then
        echo -e "${red_c}$log Error: requires: docker-init binary, found: none${no_c}" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi

    docker_location="$(which docker)"
    docker_init_location="$(which docker-init)"
    weave_location="${docker_location/docker/weave}"
}

ensure_installed() {
    if [[ $1 == "" ]]; then
        echo -e "${red_c}$log Error: clusterlite is not installed${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
}

ensure_not_installed() {
    if [[ $1 != "" ]]; then
        echo -e "${red_c}$log Error: clusterlite is already installed${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: prerequisites not satisfied${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
}

launch_etcd() {
    weave_socket=$1
    volume=$2
    token=$3
    etcd_ip=$4
    etcd_seeds=$5

    echo -e "${log} starting etcd server"
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

install_action() {
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

    echo -e "${gray_c}${log} installing:${no_c}"
    echo -e "${gray_c}${log} seed_id    => ${seed_id}${no_c}"
    echo -e "${gray_c}${log} seeds      => ${seeds}${no_c}"
    echo -e "${gray_c}${log} etcd_ip    => ${etcd_ip}${no_c}"
    echo -e "${gray_c}${log} etcd_seeds => ${etcd_seeds}${no_c}"
    echo -e "${gray_c}${log} volume     => ${volume}${no_c}"
    echo -e "${gray_c}${log} token      => ${token}${no_c}"
    echo -e "${gray_c}${log} placement  => ${placement}${no_c}"
    echo -e "${gray_c}${log} public_ip  => ${public_ip}${no_c}"

    weave_seed_name=""
    if [[ ${seed_id} != "" ]]; then
        weave_seed_name="--name ::${seed_id}"
    fi

    echo "${log} downloading clusterlite images"
    docker pull ${weave_image}
    docker pull ${proxy_image}
    docker pull ${etcd_image}

    echo "${log} extracting weave script"
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
    cp ${docker_init_location} ${volume}

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
    # TODO implement retry to allow nodes to join in parallel in any order
    docker ${weave_socket} run --name clusterlite-bootstrap -i --rm --init \
        --hostname clusterlite-bootstrap.clusterlite.local \
        --env CONTAINER_NAME=clusterlite-bootstrap \
        --env SERVICE_NAME=clusterlite-bootstrap.clusterlite.local \
        --volume /var/lib/clusterlite/nodeid.txt:/data/nodeid.txt \
        ${proxy_image} /run-proxy-allocate.sh "${weave_name}" \
            "${token}" "${volume}" "${placement}" "${public_ip}" "${seeds}" "${seed_id}"

    echo "${log} starting docker proxy"
    docker_proxy_ip $(cat /var/lib/clusterlite/nodeid.txt)
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}
    docker ${weave_socket} run --name clusterlite-proxy -dti --init \
        --hostname clusterlite-proxy.clusterlite.local \
        --env WEAVE_CIDR=${docker_proxy_ip_result}/12 \
        --env CONTAINER_NAME=clusterlite-proxy \
        --env SERVICE_NAME=clusterlite-proxy.clusterlite.local \
        --volume ${weave_run}:/var/run/weave:ro \
        --volume ${volume}:/data \
        --restart always \
        ${proxy_image} /run-proxy.sh

    if [[ ${seed_id} != "1" && ${etcd_ip} != "" ]]; then
        launch_etcd ${weave_socket} ${volume} ${token} ${etcd_ip} ${etcd_seeds}
    fi

    echo -e "${green_c}$log install succeeded${no_c}"
}

uninstall_action() {
    node_id=$1
    seed_id=$2
    volume=$3

    echo "${log} stopping proxy server"
    docker exec -i clusterlite-proxy /run-proxy-remove.sh ${node_id} || \
        echo -e "${red_c}${log} warning: failure to detach the node${no_c}"
    docker stop clusterlite-proxy || \
        echo -e "${red_c}${log} warning: failure to stop clusterlite-proxy container${no_c}"
    docker rm clusterlite-proxy || \
        echo -e "${red_c}${log} warning: failure to remove clusterlite-proxy container${no_c}"

    if [[ ${seed_id} != "" ]]; then
        echo "${log} stopping etcd server"
        docker exec -i clusterlite-etcd /run-etcd-remove.sh || \
            echo -e "${red_c}${log} warning: failure to detach clusterlite-etcd server${no_c}"
        docker stop clusterlite-etcd || \
            echo -e "${red_c}${log} warning: failure to stop clusterlite-etcd container${no_c}"
        docker rm clusterlite-etcd || \
            echo -e "${red_c}${log} warning: failure to remove clusterlite-etcd container${no_c}"
        rm -Rf ${volume}/clusterlite-etcd || \
            echo -e "${red_c}${log} warning: failure to remove ${volume}/clusterlite-etcd data${no_c}"
    fi

    echo "${log} uninstalling weave network"
    # see https://www.weave.works/docs/net/latest/ipam/stop-remove-peers-ipam/
    ${weave_location} reset || echo -e "${red_c}${log} warning: failure to reset weave network${no_c}"

    echo "${log} uninstalling data directory"
    rm -Rf ${volume} || echo -e "${red_c}${log} warning: ${volume} has not been removed${no_c}"
    rm -Rf /var/lib/clusterlite || echo -e "${red_c}${log} warning: /var/lib/clusterlite has not been removed${no_c}"

    echo -e "${green_c}$log uninstall succeeded${no_c}"
}

expose_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        echo -e "${red_c}$log Error: unknown argument $2${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
    ${weave_location} expose
}

hide_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        echo -e "${red_c}$log Error: unknown argument $2${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
    ${weave_location} hide
}

lookup_action() {
    used=$1
    if [[ ! -z $3 ]]; then
        echo -e "${red_c}$log Error: unknown argument $3${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
    if [[ -z $2 ]]; then
        echo -e "${red_c}$log Error: name to lookup argument is required${no_c}" >&2
        echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
        echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
        debug "failure: action aborted" && exit 1
    fi
    ${weave_location} dns-lookup $2
}

docker_action() {
    node_ids_and_proxy_ips=${1//[,]/ }
    shift
    shift
    cmd=""
    # search for nodes parameter and remove it from the command line
    capture_next="false"
    nodes_regexp="^[-][-]?nodes[=](.*)"
    for i in "$@"; do
        if [[ ${capture_next} == "true" ]]; then
            debug "matches node parameter: ${i}"
            capture_next="false"
        elif [[ ${i} == "--nodes" || ${i} == "-nodes" ]]; then
            capture_next="true"
        elif [[ ${i} =~ ${nodes_regexp} ]]; then
            debug "matches node parameter: ${BASH_REMATCH[1]}"
        else
            cmd="$cmd $i"
        fi
    done

    retcode=0
    hide_result=$(${weave_location} hide)
    expose_result=$(${weave_location} expose)
    for node_id_and_proxy_ip in ${node_ids_and_proxy_ips}; do
        node_id="${node_id_and_proxy_ip/[:]*/}"
        proxy_ip="${node_id_and_proxy_ip/[^:]:/}"
        # execute docker command and add prefix to stdout and stderr streams
        { { ${docker_location} -H tcp://${proxy_ip}:2375 ${cmd} 2>&3; } 2>&3 | \
            sed "s/^/[${node_id}] /"; } 3>&1 1>&2 | \
            sed "s/^/[${node_id}] /"
        [[ ${PIPESTATUS[0]} == "0" ]] || retcode=1
    done
    if [[ ${hide_result} == "" ]];then
        # it was previously hidden, so hide it back to the initial state
        # TODO may not reach this point if the above is interrupted, eg. Ctrl-C
        hide_result=$(${weave_location} hide)
    fi
    return ${retcode}
}

run() {
    # TODO ensure sudo check

    # handle debug argument
    if [[ $1 == "--debug" ]]; then
        debug_on="true"
        shift
    fi

    # handle help argument
    for i in "$@"; do
        if [[ ${i} == "--help" || ${i} == "-help" ]]; then
            usage_no_exit
            debug "success: action completed" && exit 0
        fi
    done

    # check minimum required docker is installed
    ensure_docker

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
    weave_config=""
    if [[ -f ${weave_location} ]]; then
        if [[ $(docker ps | grep weave | wc -l) != "0" ]]; then
            weave_config=$(${weave_location} config)
        fi
    fi

    # capture clusterlite state
    debug "capturing clusterlite state"
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

    # search for source parameter and place it to the working directory
    capture_next="false"
    source_path="/nonexisting/path/to/some/where"
    source_regexp="^[-][-]?source[=](.*)"
    for i in "$@"; do
        if [[ ${capture_next} == "true" ]]; then
            source_path=${i}
            break
        fi
        if [[ ${i} == "--source" || ${i} == "-source" ]]; then
            capture_next="true"
        fi
        if [[ ${i} =~ ${source_regexp} ]]; then
            source_path="${BASH_REMATCH[1]}"
            break
        fi
    done
    if [[ -f ${source_path} ]]; then
        cp ${source_path} ${clusterlite_data}
    fi

    #
    # prepare execution command
    #
    debug "preparing execution command"
    package_dir=${SCRIPT_DIR}/target/universal
    package_path=${package_dir}/clusterlite-${version_system}.zip
    package_md5=${package_dir}/clusterlite.md5
    package_unpacked=${package_dir}/clusterlite
    if [[ ! -f ${package_path} ]];
    then
        debug "production mode"
        docker_command_package_volume=""
    else
        debug "development mode"
        md5_current=$(md5sum ${package_path} | awk '{print $1}')
        if [[ ! -f ${package_md5} ]] || [[ ${md5_current} != "$(cat ${package_md5})" ]] || [[ ! -d ${package_unpacked} ]]
        then
            # install unzip if it does not exist
            echo -e "$gray_c"
            if [[ $(which unzip || echo) == "" ]];
            then
                if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
                then
                    # ubuntu supports automated installation
                    apt-get -y update || (echo "${red_c}apt-get update failed, are proxy settings correct?{$no_c}" && exit 1)
                    apt-get -qq -y install --no-install-recommends unzip jq
                else
                    echo -e "${red_c}$log Error: unzip has not been found, please install unzip utility${no_c}" >&2
                    exit 1
                fi
            fi
            rm -Rf ${package_dir}/clusterlite
            unzip -o ${package_path} -d ${package_dir} 1>&2
            echo -e "$no_c"
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
        --env CLUSTERLITE_DEBUG=${debug_on} \
        --env IPV4_ADDRESSES=$IPV4_ADDRESSES \
        --env IPV6_ADDRESSES=$IPV6_ADDRESSES \
        --volume ${clusterlite_volume}:/data \
        $docker_command_package_volume \
        ${system_image} /opt/clusterlite/bin/clusterlite"

    #
    # execute the command
    #
    log_out=${clusterlite_data}/stdout.log
    case $1 in
        help)
            usage_no_exit
            debug "success: action completed" && exit 0
        ;;
        version)
            version_action
            debug "success: action completed" && exit 0
        ;;
        install)
            ensure_not_installed ${node_id}
            echo "${log} downloading clusterlite system image"
            docker pull ${system_image}
            tmp_out=${clusterlite_data}/tmpout.log
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} > ${tmp_out} || (debug "failure: action aborted" && exit 1)
            install_action $(cat ${tmp_out})

            if [[ ${volume} == "" && -f "/var/lib/clusterlite/volume.txt" ]];
            then
                # volume directory has been installed, save installation logs
                volume=$(cat /var/lib/clusterlite/volume.txt)
                debug "saving $volume/clusterlite/$CLUSTERLITE_ID"
                cp -R ${clusterlite_data} ${volume}/clusterlite
            fi
            debug "success: action completed" && exit 0
        ;;
        uninstall)
            ensure_installed ${node_id}
            tmp_out=${clusterlite_data}/tmpout.log
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} > ${tmp_out} || (debug "failure: action aborted" && exit 1)
            uninstall_action ${node_id} ${seed_id} ${volume}
            debug "success: action completed" && exit 0
        ;;
        docker)
            ensure_installed ${node_id}
            capture_next="false"
            nodes_param_name=""
            nodes_param=""
            nodes_regexp="^[-][-]?nodes[=](.*)"
            for i in "$@"; do
                if [[ ${capture_next} == "true" ]]; then
                    nodes_param_name="--nodes"
                    nodes_param=${i}
                    capture_next="false"
                    # do not break, search for multiple nodes parameters
                fi
                if [[ ${i} == "--nodes" || ${i} == "-nodes" ]]; then
                    capture_next="true"
                fi
                if [[ ${i} =~ ${nodes_regexp} ]]; then
                    nodes_param_name="--nodes"
                    nodes_param="${BASH_REMATCH[1]}"
                    # do not break, search for multiple nodes parameters
                fi
            done
            docker_command="${docker_command} proxy-info ${nodes_param_name} ${nodes_param}"
            debug "executing ${docker_command}"
            tmp_out=${clusterlite_data}/tmpout.log
            ${docker_command} > ${tmp_out} || (debug "failure: action aborted" && exit 1)
            proxy_info_param=$(cat ${tmp_out})
            debug "proxy info ${proxy_info_param}"
            docker_action ${proxy_info_param} $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        login|logout|plan|apply|destroy|upload|download|services|nodes|users|files)
            ensure_installed ${node_id}
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} | tee ${log_out}
            [[ ${PIPESTATUS[0]} == "0" ]] || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        expose)
            ensure_installed ${node_id}
            expose_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        hide)
            ensure_installed ${node_id}
            hide_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        lookup)
            ensure_installed ${node_id}
            lookup_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        "")
            echo -e "${red_c}$log Error: action argument is required${no_c}" >&2
            echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
            echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
            debug "failure: action aborted" && exit 1
        ;;
        *)
            echo -e "${red_c}$log Error: unknown action '$1'${no_c}" >&2
            echo -e "${red_c}$log Try 'clusterlite help' for more information.${no_c}" >&2
            echo -e "${red_c}$log failure: invalid argument(s)${no_c}" >&2
            debug "failure: action aborted" && exit 1
        ;;
    esac
}

run $@ # wrap in a function to prevent partial download