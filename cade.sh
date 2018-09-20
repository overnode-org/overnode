#!/bin/bash

#
# Cade:
#    CADE is Containerized Application DEployment toolkit
#    for automated deployment and management of distributed applications
#    based on micro-services architecture.
#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#
# Prerequisites:
# - Ubuntu 16.04 machine (or another Linux with installed docker 1.13.1)
#   with valid hostname, IP interface, DNS, proxy, apt-get configuration
# - Internet connection
#

version_system=0.7.1
version_weave=1.9.7
version_proxy=3.6.2
version_etcd=3.1.0
version_terraform=0.9.8
version_docker_min=1.13.0 # should be higher than weave requirement

set -e

log="[cade]"

system_image="cadeworks/system:${version_system}"
weave_image="cadeworks/weave:${version_weave}"
proxy_image="cadeworks/proxy:${version_proxy}"
etcd_image="cadeworks/etcd:${version_etcd}"

debug_on="false"

docker_location="docker" # will be updated to full path later
docker_init_location="docker-init" # will be updated to full path later
weave_location="weave" # will be updated to full path later

green_c='\033[0;32m'
red_c='\033[0;31m'
yellow_c='\033[0;33m'
gray_c='\033[1;30m'
no_c='\033[0;37m' # white

function set_console_color() {
    printf "$1" >&2
}
function set_console_normal() {
    printf "${no_c}" >&2
}
trap set_console_normal EXIT

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo -e "${gray_c}$log $@${no_c}")
    fi
}
info() {
    (>&2 echo -e "${gray_c}$log $@${no_c}")
}
warn() {
    (>&2 echo -e "${yellow_c}$log $@${no_c}")
}
error() {
    (>&2 echo -e "${red_c}$log $@${no_c}")
}
println() {
    echo -e "$@"
}

exit_success() {
    debug "success: action completed"
    exit 0
}

exit_error() {
    debug "failure: action aborted"
    exit 1
}

usage_no_exit() {

line="${gray_c}----------------------------------------------------------------------------${no_c}"

printf """> ${green_c}cade [--debug] <action> [OPTIONS]${no_c}

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
  ${green_c}install${no_c}   Install cade node on the current host and join the cluster.
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
    ${green_c}[--volume /var/lib/cade]${no_c}
            Directory where stateful services will persist data. Each service
            will get it's own sub-directory within the defined volume.
    ${green_c}[--public-address <ip-address>]${no_c}
            Public IP address of the host, if it exists and requires exposure.
    ${green_c}[--placement default]${no_c}
            Role allocation for a node. A node schedules services according to
            the matching placement defined in the configuration file,
            which is set via 'apply' action.
    ${gray_c}Example: initiate the cluster with the first seed node:
      host1> cade install --token abcdef0123456789 --seeds host1
    Example: add 2 other hosts as seed nodes:
      host2> cade install --token abcdef0123456789 --seeds host1,host2,host3
      host3> cade install --token abcdef0123456789 --seeds host1,host2,host3
    Example: add 1 more host as regular node:
      host4> cade install --token abcdef0123456789 --seeds host1,host2,host3${no_c}
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
    ${green_c}--source </path/to/text/file>${no_c}
            Path to a file to upload. If not specified, target parameter
            should be specified and the action will cause deletion
            of the file referred by the target parameter.
    ${green_c}[--target <file-id>]${no_c}
            Reference of a file to upload to or delete. If not specified,
            source parameter should be specified and target parameter
            will be set to source file name by default.
  ${green_c}download${no_c}  Print content of a file by it's reference.
    ${green_c}[--target <file-id>]${no_c}
            Reference of a file to print. Use 'files' action to get the list
            of available files. If the option is not specified,
            it prints current YAML configuration for 'plan'/'apply' actions.
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
    ${green_c}[--retries 10]${no_c}
            Number of times to retry downloading of an image when network
            connection to a registry of the image is lost.
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
      hostX> cade docker ps --nodes 1
    Example: print logs for my-service container running on nodes 1 and 2:
      hostX> cade docker logs my-service --nodes 1,2
    Example: print running processes in my-service container for all nodes:
      hostX> cade docker exec -it --rm my-service ps -ef${no_c}
    Example: print persisted volume usage statistics on every node
      hostX> cade docker exec -it cade-proxy du /data
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
    println "CADE - Containerized Application DEployment toolkit."
    println "    system version: $version_system"
    println "    weave version:  $version_weave"
    println "    etcd version:   $version_etcd"
    println "    proxy version:  $version_proxy"
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
    if [ "$(which docker | wc -l)" -eq "0" ]
    then
        error "Error: requires: docker, found: none"
        error "failure: prerequisites not satisfied"
        exit_error
    fi

    if ! docker_version=$(docker -v | sed -n -e 's|^Docker version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*|\1|p') || [ -z "$docker_version" ] ; then
        error "Error: unable to parse docker version"
        error "failure: prerequisites not satisfied"
        exit_error
    fi

    if version_lt ${docker_version} ${version_docker_min} ; then
        error "Error: Docker version $version_docker_min or later is required; you are running $docker_version"
        error "failure: prerequisites not satisfied"
        exit_error
    fi

    # should pass the following if the previous is passed
    if [ "$(which docker-init | wc -l)" -eq "0" ]
    then
        error "Error: requires: docker-init binary, found: none"
        error "failure: prerequisites not satisfied"
        exit_error
    fi

    docker_location="$(which docker)"
    docker_init_location="$(which docker-init)"
    weave_location="${docker_location/docker/weave}"
}

ensure_root() {
    if [ "$(id -u)" -ne "0" ]
    then
        error "Error: root privileges required"
        error "Try 'sudo cade $@'."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

ensure_installed() {
    if [[ $1 == "" ]]; then
        error "Error: cade is not installed"
        error "Try 'cade help' for more information."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

ensure_not_installed() {
    if [[ $1 != "" ]]; then
        error "Error: cade is already installed"
        error "Try 'cade help' for more information."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

launch_etcd() {
    weave_socket=$1
    volume=$2
    token=$3
    etcd_ip=$4
    etcd_seeds=$5

    warn "starting etcd server"
    set_console_color "${gray_c}"
    docker ${weave_socket} run --name cade-etcd -dti --init \
        --hostname cade-etcd.cade.local \
        --env WEAVE_CIDR=${etcd_ip}/12 \
        --env CONTAINER_IP=${etcd_ip} \
        --env CONTAINER_NAME=cade-etcd \
        --env SERVICE_NAME=cade-etcd.cade.local \
        --env CADE_TOKEN=${token} \
        --volume ${volume}/cade-etcd:/data \
        --restart always \
        ${etcd_image} /run-etcd.sh ${etcd_seeds//[,]/ } 1>&2
    set_console_normal
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

    warn "installing"
    info "    seed_id    => ${seed_id}"
    info "    seeds      => ${seeds}"
    info "    etcd_ip    => ${etcd_ip}"
    info "    etcd_seeds => ${etcd_seeds}"
    info "    volume     => ${volume}"
    info "    token      => ${token}"
    info "    placement  => ${placement}"
    info "    public_ip  => ${public_ip}"

    weave_seed_name=""
    if [[ ${seed_id} != "" ]]; then
        weave_seed_name="--name ::${seed_id}"
    fi

    warn "downloading cade images"
    set_console_color "${gray_c}"
    docker pull ${weave_image} 1>&2
    docker pull ${proxy_image} 1>&2
    docker pull ${etcd_image} 1>&2
    set_console_normal

    warn "extracting weave script"
    set_console_color "${gray_c}"
    docker run --rm -i ${weave_image} > ${weave_location}
    set_console_normal
    chmod u+x ${weave_location}

    warn "downloading weave images"
    #${weave_location} setup

    warn "installing data directory"
    if [ ! -d /var/lib/cade ]; then
        mkdir /var/lib/cade || true
    fi
    echo ${volume} > /var/lib/cade/volume.txt
    echo ${seed_id} > /var/lib/cade/seedid.txt
    echo "" > /var/lib/cade/nodeid.txt
    if [ ! -d ${volume} ]; then
        mkdir ${volume} || true
    fi
    if [ ! -d ${volume}/cade ]; then
        mkdir ${volume}/cade || true
    fi
    cp ${docker_init_location} ${volume}

    warn "installing weave network"
    set_console_color "${gray_c}"
    export CHECKPOINT_DISABLE=1 # disabling weave check for new versions
    # launching weave node for uniform dynamic cluster with encryption is enabled
    # see https://www.weave.works/docs/net/latest/operational-guide/uniform-dynamic-cluster/
    # automated range allocation does not require seeds to reach a consensus
    # because the range is split in advance by seeds enumeration
    # see https://github.com/weaveworks/weave/blob/master/site/ipam.md#via-seed
    ${weave_location} launch-router --password ${token} \
        --dns-domain="cade.local." \
        --ipalloc-range 10.47.255.0/24 --ipalloc-default-subnet 10.32.0.0/12 \
        ${weave_seed_name} --ipalloc-init seed=::1,::2,::3 ${seeds//,/ } 1>&2
    # integrate with docker using weave proxy, it is more reliable than weave plugin
    ${weave_location} launch-proxy --rewrite-inspect 1>&2
    set_console_normal

    weave_socket=$(${weave_location} config)
    if [[ ${seed_id} == "1" ]]; then
        launch_etcd ${weave_socket} ${volume} ${token} ${etcd_ip} ${etcd_seeds}
    fi

    warn "allocating node id"
    set_console_color "${gray_c}"
    weave_name=$(${weave_location} status | grep Name | awk '{print $2}')
    # This command blocks until the node joins the cluster and quorum assigns new id
    # TODO if seed is unreachable, it confuses user, status and progress is required
    # TODO if seed is unreachable and a user kills it Ctrl-C,
    # TODO the current node remains with weave net running, it needs to be reverted
    docker ${weave_socket} run --name cade-bootstrap -i --rm --init \
        --hostname cade-bootstrap.cade.local \
        --env CONTAINER_NAME=cade-bootstrap \
        --env SERVICE_NAME=cade-bootstrap.cade.local \
        --volume /var/lib/cade/nodeid.txt:/data/nodeid.txt \
        ${proxy_image} /run-proxy-allocate.sh "${weave_name}" \
            "${token}" "${volume}" "${placement}" "${public_ip}" "${seeds}" "${seed_id}" 1>&2
    set_console_normal

    warn "starting docker proxy"
    set_console_color "${gray_c}"
    node_id=$(cat /var/lib/cade/nodeid.txt)
    docker_proxy_ip ${node_id}
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}
    docker ${weave_socket} run --name cade-proxy -dti --init \
        --hostname cade-proxy.cade.local \
        --env WEAVE_CIDR=${docker_proxy_ip_result}/12 \
        --env CONTAINER_NAME=cade-proxy \
        --env SERVICE_NAME=cade-proxy.cade.local \
        --volume ${weave_run}:/var/run/weave:ro \
        --volume ${volume}:/data \
        --restart always \
        ${proxy_image} /run-proxy.sh 1>&2
    set_console_normal

    if [[ ${seed_id} != "1" && ${etcd_ip} != "" ]]; then
        launch_etcd ${weave_socket} ${volume} ${token} ${etcd_ip} ${etcd_seeds}
    fi

    println "[$node_id] Node installed"
}

uninstall_action() {
    node_id=$1
    seed_id=$2
    volume=$3

    warn "stopping proxy server"
    set_console_color "${gray_c}"
    docker exec -i cade-proxy /run-proxy-remove.sh ${node_id} 1>&2 || \
        warn "failure to detach the node"
    set_console_color "${gray_c}"
    docker stop cade-proxy 1>&2 || \
        warn "failure to stop cade-proxy container"
    set_console_color "${gray_c}"
    docker rm cade-proxy 1>&2 || \
        warn "failure to remove cade-proxy container"
    set_console_normal

    if [[ ${seed_id} != "" ]]; then
        warn "stopping etcd server"
        set_console_color "${gray_c}"
        docker exec -i cade-etcd /run-etcd-remove.sh 1>&2 || \
            warn "failure to detach cade-etcd server"
        set_console_color "${gray_c}"
        docker stop cade-etcd 1>&2 || \
            warn "failure to stop cade-etcd container"
        set_console_color "${gray_c}"
        docker rm cade-etcd 1>&2 || \
            warn "failure to remove cade-etcd container"
        set_console_color "${gray_c}"
        rm -Rf ${volume}/cade-etcd 1>&2 || \
            warn "failure to remove ${volume}/cade-etcd data"
        set_console_normal
    fi

    warn "uninstalling weave network"
    set_console_color "${gray_c}"
    # see https://www.weave.works/docs/net/latest/ipam/stop-remove-peers-ipam/
    ${weave_location} reset 1>&2 || warn "failure to reset weave network"
    set_console_normal

    warn "uninstalling data directory"
    set_console_color "${gray_c}"
    rm -Rf ${volume} 1>&2 || warn "${volume} has not been removed"
    set_console_color "${gray_c}"
    rm -Rf /var/lib/cade 1>&2 || warn "/var/lib/cade has not been removed"
    set_console_normal

    println "[$node_id] Node unistalled"
}

expose_weave() {
    ${weave_location} expose
}
expose_weave_silent() {
    expose_weave > /dev/null
}
expose_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        error "Error: unknown argument $2"
        error "Try 'cade help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    expose_weave
}

hide_weave(){
    ${weave_location} hide
}
hide_weave_silent(){
    hide_weave > /dev/null
}
hide_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        error "Error: unknown argument $2"
        error "Try 'cade help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    hide_weave
}

lookup_action() {
    used=$1
    if [[ ! -z $3 ]]; then
        error "Error: unknown argument $3"
        error "Try 'cade help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    if [[ -z $2 ]]; then
        error "Error: name to lookup argument is required"
        error "Try 'cade help' for more information."
        error "failure: invalid argument(s)"
        exit_error
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

    hide_result=$(hide_weave)
    if [[ ${hide_result} == "" ]];then
        # it was previously hidden, so hide it back to the initial state on exit
        trap hide_weave_silent EXIT
    fi
    expose_weave_silent
    for node_id_and_proxy_ip in ${node_ids_and_proxy_ips}; do
        node_id="${node_id_and_proxy_ip/[:]*/}"
        proxy_ip="${node_id_and_proxy_ip/[^:]:/}"
        warn "[${node_id}] executing docker command: ${cmd}"
        ${docker_location} -H tcp://${proxy_ip}:2375 ${cmd} || exit_error
    done
}

run() {
    # TODO detect upgrade case and prevent from running any commands without executing upgrade command
    # TODO currently it spits like the following in white color
    # TODO Unable to find image 'cadeworks/system:0.5.0' locally
    # TODO 0.5.0: Pulling from cadeworks/system

    # handle debug argument
    if [[ $1 == "--debug" ]]; then
        debug_on="true"
        shift
    fi

    # handle help argument
    for i in "$@"; do
        if [[ ${i} == "--help" || ${i} == "-help" ]]; then
            usage_no_exit
            exit_success
        fi
    done

    # handle version command
    if [[ $1 == "version" || ($1 == "--debug" && $2 == "version") ]]; then
        version_action
        exit_success
    fi

    # all other commands require root
    ensure_root $@

    # check minimum required docker is installed
    ensure_docker

    #
    # Prepare the environment and command
    #
    debug "preparing the environment"
    operation_id=$(date +%Y%m%d-%H%M%S.%N-%Z)
    hostname_f=$(hostname -f)
    if [[ $1 == "install" || ($1 == "--debug" && $2 == "install") ]]; then
        # capture more details only for install command
        ipv4_addresses=$(echo $(ip addr | grep -v inet6 | grep inet | tr "/" " " | awk '{print $2}') | tr " " ",")
        ipv6_addresses=$(echo $(ip addr | grep inet6 | tr "/" " " | awk '{print $2}') | tr " " ",")
    else
        ipv4_addresses=""
        ipv6_addresses=""
    fi

    # capture weave state
    debug "capturing weave state"
    weave_config=""
    if [[ -f ${weave_location} ]]; then
        if [[ $(docker ps | grep weave | wc -l) != "0" ]]; then
            weave_config=$(${weave_location} config)
        fi
    fi

    # capture cade state
    debug "capturing cade state"
    if [[ -f "/var/lib/cade/volume.txt" ]];
    then
        volume=$(cat /var/lib/cade/volume.txt)
    else
        volume=""
    fi
    if [[ -f "/var/lib/cade/nodeid.txt" ]];
    then
        node_id=$(cat /var/lib/cade/nodeid.txt)
    else
        node_id=""
    fi
    if [[ -f "/var/lib/cade/seedid.txt" ]];
    then
        seed_id=$(cat /var/lib/cade/seedid.txt)
    else
        seed_id=""
    fi
    if [[ ${volume} == "" ]];
    then
        if [ ! -d /tmp/cade ]; then
            mkdir /tmp/cade
        fi
        cade_volume="/tmp/cade"
    else
        cade_volume="${volume}/cade"
    fi
    cade_data="${cade_volume}/${operation_id}"

    # prepare working directory for an action
    debug "preparing working directory"
    mkdir ${cade_data}

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
        cp ${config_path} ${cade_data}/apply-config.yaml
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
        cp ${source_path} ${cade_data}
    fi

    #
    # prepare execution command
    #
    debug "preparing execution command"
    script_dir=$(cd "$(dirname "$0")" && pwd)
    package_dir=${script_dir}/target/universal
    package_path=${package_dir}/cade-${version_system}.zip
    package_md5=${package_dir}/cade.md5
    package_unpacked=${package_dir}/cade
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
            set_console_color "${gray_c}"
            if [ "$(which unzip | wc -l)" -eq "0" ]
            then
                if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
                then
                    # ubuntu supports automated installation
                    apt-get -y update 1>&2 || (error "apt-get update failed, are proxy settings correct?" && exit_error)
                    apt-get -qq -y install --no-install-recommends unzip jq 1>&2
                else
                    error "Error: unzip has not been found, please install unzip utility"
                    exit_error
                fi
            fi
            rm -Rf ${package_dir}/cade 1>&2
            unzip -o ${package_path} -d ${package_dir} 1>&2
            set_console_normal
            echo ${md5_current} > ${package_md5}
        fi
        docker_command_package_volume="--volume ${package_unpacked}:/opt/cade"
    fi
    docker_command="docker ${weave_config} run --rm -i \
        --env CADE_OPERATION_ID=${operation_id} \
        --env CADE_NODE_ID=${node_id} \
        --env CADE_VOLUME=${volume} \
        --env CADE_SEED_ID=${seed_id} \
        --env CADE_DEBUG=${debug_on} \
        --env CADE_VERSION=${version_system} \
        --env CADE_IPV4_ADDRESSES=${ipv4_addresses} \
        --env CADE_IPV6_ADDRESSES=${ipv6_addresses} \
        --env CADE_HOSTNAME=${hostname_f} \
        --volume ${cade_volume}:/data \
        $docker_command_package_volume \
        ${system_image} /opt/cade/bin/cade"

    #
    # execute the command
    #
    log_out=${cade_data}/stdout.log
    case $1 in
        help)
            usage_no_exit
            exit_success
        ;;
        version)
            version_action
            exit_success
        ;;
        install)
            ensure_not_installed ${node_id}
            warn "downloading cade system image"
            set_console_color "${gray_c}"
            docker pull ${system_image} 1>&2
            set_console_normal
            tmp_out=${cade_data}/tmpout.log
            # forward /etc/hosts data to inside of a container for correct names resolution
            cp /etc/hosts ${cade_data} || warn "/etc/hosts is not accessible"
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} > ${tmp_out} || exit_error
            install_action $(cat ${tmp_out})

            if [[ -f "/var/lib/cade/volume.txt" ]];
            then
                # volume directory has been installed, save installation logs
                volume=$(cat /var/lib/cade/volume.txt)
                # but only when it is not installation on top of existing
                if [[ "${volume}/cade" != ${cade_volume} ]];
                then
                    debug "moving ${cade_data} to ${volume}/cade"
                    mv ${cade_data} ${volume}/cade
                fi
            fi
            exit_success
        ;;
        uninstall)
            ensure_installed ${node_id}
            tmp_out=${cade_data}/tmpout.log
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} > ${tmp_out} || exit_error
            uninstall_action ${node_id} ${seed_id} ${volume}
            exit_success
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
            tmp_out=${cade_data}/tmpout.log
            ${docker_command} > ${tmp_out} || exit_error
            proxy_info_param=$(cat ${tmp_out})
            debug "proxy info ${proxy_info_param}"
            docker_action ${proxy_info_param} $@ || exit_error
            exit_success
        ;;
        login|logout|plan|apply|destroy|upload|download|services|nodes|users|files)
            ensure_installed ${node_id}
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} | tee ${log_out}
            [[ ${PIPESTATUS[0]} == "0" ]] || exit_error
            exit_success
        ;;
        expose)
            ensure_installed ${node_id}
            expose_action $@ || exit_error
            exit_success
        ;;
        hide)
            ensure_installed ${node_id}
            hide_action $@ || exit_error
            exit_success
        ;;
        lookup)
            ensure_installed ${node_id}
            lookup_action $@ || exit_error
            exit_success
        ;;
        "")
            error "Error: action argument is required"
            error "Try 'cade help' for more information."
            error "ailure: invalid argument(s)"
            exit_error
        ;;
        *)
            error "Error: unknown action '$1'"
            error "Try 'cade help' for more information."
            error "failure: invalid argument(s)"
            exit_error
        ;;
    esac
}

run $@ # wrap in a function to prevent partial download
