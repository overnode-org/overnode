#!/bin/bash

set -e
set -o errexit -o pipefail -o noclobber -o nounset

version_docker=19.03.8
version_compose=1.25.4
version_weave=2.6.2
version_proxy=1.7.3.4-r0
version_system=0.8.8

provider_proxy="alpine/socat"
provider_compose="docker/compose"

image_proxy="${provider_proxy}:${version_proxy}"
image_compose="${provider_compose}:${version_compose}"

volume="/data"

log="[overnode]"
debug_on="false"

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
debug_cmd() {
    debug "${yellow_c}>>>${gray_c} $@" 
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

run_cmd() {
    debug_cmd $@
    $@
}

exit_success() {
    debug "success: action completed"
    exit 0
}

exit_error() {
    debug "failure: action aborted"
    exit 1
}

exists(){
    if [ "$2" != in ]; then
        echo "Incorrect usage."
        echo "Correct usage: exists {key} in {array}"
        return
    fi   
    eval '[ ${'$3'[$1]+muahaha} ]'  
}

usage_no_exit() {

line="${gray_c}----------------------------------------------------------------------------${no_c}"

printf """> ${green_c}overnode [--debug] <action> [OPTIONS]${no_c}

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
  ${green_c}launch${no_c}   Install overnode node on the current host and join the cluster.
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
    ${green_c}[--volume /data]${no_c}
            Directory where stateful services will persist data. Each service
            will get it's own sub-directory within the defined volume.
    ${green_c}[--public-address <ip-address>]${no_c}
            Public IP address of the host, if it exists and requires exposure.
    ${green_c}[--placement default]${no_c}
            Role allocation for a node. A node schedules services according to
            the matching placement defined in the configuration file,
            which is set via 'apply' action.
    ${gray_c}Example: initiate the cluster with the first seed node:
      host1> overnode launch --token abcdef0123456789 --seeds host1
    Example: overnode 2 other hosts as seed nodes:
      host2> overnode launch --token abcdef0123456789 --seeds host1,host2,host3
      host3> overnode launch --token abcdef0123456789 --seeds host1,host2,host3
    Example: add 1 more host as regular node:
      host4> overnode install --token abcdef0123456789 --seeds host1,host2,host3${no_c}
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
      hostX> overnode docker ps --nodes 1
    Example: print logs for my-service container running on nodes 1 and 2:
      hostX> overnode docker logs my-service --nodes 1,2
    Example: print running processes in my-service container for all nodes:
      hostX> overnode docker exec -it --rm my-service ps -ef${no_c}
    Example: print persisted volume usage statistics on every node
      hostX> overnode docker exec -it overnode du /data
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

ensure_no_args() {
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                exit_error
                ;;
        esac
    done
    
    if [[ ! -z "$@" ]]
    then
        error "Error: unexpected argument(s): $@"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
}

ensure_one_arg() {
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 1 ]
    then
        error "Error: expected one argument."
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
}

version_action() {
    shift
    ensure_no_args $@
    
    println "Overnode - Multi-node Docker containers orchestration."
    println "    version:    $version_system"
    println "    docker:  $version_docker [default], $(docker version 2>&1 | grep Version | head -n1 | awk '{print $2}') [installed]"
    println "    weave:   $version_weave [default], $(weave version 2>&1 | grep script | head -n1 | awk '{print $3}') [installed]"
    println "    compose: $version_compose"
    println "    agent:   $version_proxy"
}

# Given $1 and $2 as semantic version numbers like 3.1.2, return [ $1 < $2 ]
# version_lt() {
#     VERSION_MAJOR=${1%.*.*}
#     REST=${1%.*} VERSION_MINOR=${REST#*.}
#     VERSION_PATCH=${1#*.*.}

#     MIN_VERSION_MAJOR=${2%.*.*}
#     REST=${2%.*} MIN_VERSION_MINOR=${REST#*.}
#     MIN_VERSION_PATCH=${2#*.*.}

#     if [ \( "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" \) -o \
#         \( "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a \
#         \( "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" -o \
#         \( "$VERSION_MINOR" -eq "$MIN_VERSION_MINOR" -a \
#         \( "$VERSION_PATCH" -lt "$MIN_VERSION_PATCH" \) \) \) \) ] ; then
#         return 0
#     fi
#     return 1
# }

ensure_root() {
    if [ "$(id -u)" -ne "0" ]
    then
        error "Error: root privileges required"
        error "Try 'overnode $@'."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

ensure_getopt() {
    # -allow a command to fail with !’s side effect on errexit
    # -use return value from ${PIPESTATUS[0]}, because ! hosed $?
    ! getopt --test > /dev/null 
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        error "Error: requires: getopt, found: none"
        error "Try installing getopt utility using operation system package manager."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

ensure_docker() {
    if [ "$(which docker | wc -l)" -eq "0" ]
    then
        error "Error: requires: docker, found: none"
        error "Try 'overnode install'."
        error "failure: prerequisites not satisfied"
        exit_error
    fi

    # if ! docker_version=$(docker -v | sed -n -e 's|^Docker version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*|\1|p') || [ -z "$docker_version" ] ; then
    #     error "Error: unable to parse docker version"
    #     error "Try 'overnode install'."
    #     error "failure: prerequisites not satisfied"
    #     exit_error
    # fi

    # if version_lt ${docker_version} ${version_docker_min} ; then
    #     error "Error: Docker version $version_docker_min or later is required; you are running $docker_version"
    #     error "Try 'overnode install'."
    #     error "failure: prerequisites not satisfied"
    #     exit_error
    # fi

    # should pass the following if the previous is passed
    # if [ "$(which docker-init | wc -l)" -eq "0" ]
    # then
    #     error "Error: requires: docker-init binary, found: none"
    #     error "Try 'overnode install'."
    #     error "failure: prerequisites not satisfied"
    #     exit_error
    # fi

    # docker_location="$(which docker)"
    # docker_init_location="$(which docker-init)"
    # weave_location="${docker_location/docker/weave}"
}

ensure_weave() {
    if [ "$(which weave | wc -l)" -eq "0" ]
    then
        error "Error: requires: weave, found: none"
        error "Try 'overnode install'."
        error "failure: prerequisites not satisfied"
        exit_error
    fi
}

ensure_weave_running() {
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        error "Error: weave is not running"
        error "Try 'overnode launch'."
        error "failure: prerequisites not satisfied"
        exit_error
    fi    
}

install_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=f --longoptions=force --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    force="n"
    while true; do
        case "$1" in
            --force|-f)
                force="y"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done

    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi

    installed_something="n"
    warn "installing docker"
    if [[ "$(which docker | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        (wget -q --no-cache -O - https://get.docker.com || {
            error "Error: failure to download file: https://get.docker.com"
            error "Try 'wget --no-cache -O - https://get.docker.com'"
            error "failure: prerequisites not satisfied"
            exit_error
        }) | sudo VERSION=${version_docker} sh
        set_console_normal
        installed_something="y"
        println "docker installed"
    else
        println "docker is already installed"
    fi

    warn "installing weave"
    if [ "$(which weave | wc -l)" -eq "0" ]
    then
        set_console_color "${gray_c}"
        wget -q --no-cache -O - https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave > /usr/local/bin/weave || {
            error "Error: failure to download file: https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave"
            error "Try 'wget --no-cache -O - https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave'"
            error "failure: prerequisites not satisfied"
            exit_error
        }
        chmod a+x /usr/local/bin/weave
        weave setup
        set_console_normal
        installed_something="y"
    else
        if [[ ${force} == "y" ]]
        then
            set_console_color "${gray_c}"
            [ ! -f /tmp/weave ] || rm /tmp/weave
            wget -q --no-cache -O - https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave > /tmp/weave || {
                error "Error: failure to download file: https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave"
                error "Try 'wget --no-cache -O - https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave'"
                error "failure: prerequisites not satisfied"
                exit_error
            }
            chmod a+x /tmp/weave
            /tmp/weave setup
            set_console_normal

            tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
            if [ $weave_running -eq 0 ]
            then
                set_console_color "${gray_c}"
                println "restarting weave"
                weave stop
                cp /tmp/weave /usr/local/bin/weave
                weave launch --resume # https://github.com/weaveworks/weave/issues/3050#issuecomment-326932723
                set_console_normal
            else
                cp /tmp/weave /usr/local/bin/weave
            fi
            installed_something="y"
            println "weave installed"
        else
            println "weave is already installed"
        fi
    fi
    
    warn "installing compose"
    if [[ "$(docker images | grep ${provider_compose} | grep ${version_compose} | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        docker pull ${image_compose}
        set_console_normal
        installed_something="y"
        println "compose installed"
    else
        println "compose is already installed"
    fi
    
    warn "installing agent"
    if [[ "$(docker images | grep ${provider_proxy} | grep ${version_proxy} | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        docker pull ${image_proxy}
        set_console_normal
        installed_something="y"
        println "agent installed"
    else
        println "agent is already installed"
    fi
    
    if [ "${installed_something}" == "n" ]
    then
        warn "Everything was already installed."
        warn "To upgrade, run 'overnode upgrade'."
        warn "To re-install, run 'overnode install --force'."
    fi
}

upgrade_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="version:" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    version="master"
    while true; do
        case "$1" in
            --version)
                verion=$2
                shift 2
                break
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done

    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi

    [ ! -f /tmp/install.sh ] || rm /tmp/install.sh
    wget -q --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh > /tmp/install.sh || {
        error "Error: failure to download file: https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh"
        error "Try 'wget --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh'"
        error "failure: prerequisites not satisfied"
        exit_error
    }
    chmod a+x /tmp/install.sh

    /tmp/install.sh --force || {
        error "Error: /tmp/install.sh script exited abnormally"
        error "failure: upgrade unsuccessful"
        exit_error
    }
}

launch_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=token:,id: --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    token=""
    node_id=""
    while true; do
        case "$1" in
            --token)
                token=$2
                shift 2
                ;;
            --id)
                node_id=$2
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done

    if [ -z "$token" ]
    then
        error "Error: missing required parameter 'token'"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi

    if [ -z "$node_id" ]
    then
        error "Error: missing required parameter 'id'"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi

    pat="^[1-9][0-9]?$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        error "Error: parameter 'id' is not a number from 1 to 99"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi

    warn "launching weave"
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        export CHECKPOINT_DISABLE=1
        output=$(weave launch --plugin=false --password=${token} --dns-domain=overnode.local. --rewrite-inspect \
            --ipalloc-range 10.47.255.0/24 --ipalloc-default-subnet 10.32.0.0/12 --ipalloc-init seed=::1,::2,::3 \
            --name=::${node_id} $@) && weave_running=$? || weave_running=$?
        if [[ $weave_running -ne 0 ]]
        then
            cid=$(docker ps --all | grep weave | head -n 1 | awk '{print $1}')
            error "Error: weave container is not running"
            error "Try 'docker logs ${cid}' for more information."
            error "failure: weave exited abnormally"
            return 1
        fi
        println $output
    else
        println "weave is already running"
    fi

    warn "creating ${volume}"
    if [ -d ${volume} ]
    then
        println "${volume} is already created" 
    else
        mkdir ${volume} 1>&2
    fi

    if [ -f ${volume}/nodeid.txt ]
    then
        node_id_existing=$(cat ${volume}/nodeid.txt)
        if [[ "${node_id}" != "${node_id_existing}" ]]
        then
            error "Error: this host has got different id '${node_id_existing}' assigned already"
            error "failure: invalid argument(s)"
            return 1
        fi
    else
        echo ${node_id} > ${volume}/nodeid.txt
    fi

    warn "launching agent"
    weave_socket=$(weave config)
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}

    [ -f ${volume}/proxy-config.yml ] && rm ${volume}/proxy-config.yml
    printf """
version: '3.7'
services:
    overnode:
        container_name: overnode
        hostname: overnode.overnode.local
        image: ${image_proxy}
        init: true
        environment:
            WEAVE_CIDR: 10.47.240.${node_id}/12
        volumes:
            - ${volume}:/data
            - ${weave_run}:/var/run/weave:ro
        restart: always
        network_mode: bridge
        command: TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/weave/weave.sock
""" > ${volume}/proxy-config.yml

    docker run --rm \
        -v ${volume}/proxy-config.yml:/docker-compose.yml \
        -v ${weave_run}:${weave_run}:ro \
        ${image_compose} ${weave_socket} --compatibility up -d --remove-orphans

    println "[$node_id] Node launched"
}

reset_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=purge --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    purge="n"
    while true; do
        case "$1" in
            --purge)
                purge="y"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        warn "destroying agent"
        if [ -f ${volume}/proxy-config.yml ]
        then
            docker run --rm \
                -v ${volume}/proxy-config.yml:/docker-compose.yml \
                -v /var/run/docker.sock:/var/run/docker.sock \
                ${image_compose} --compatibility down --remove-orphans

            rm ${volume}/proxy-config.yml
        else
            println "agent is not running"
        fi

        warn "destroying weave"
        weave reset --force
        println "weave is not running"
    else
        if [ $(weave ps | grep -v expose | grep -v 10.47.240 | wc -l) -ne 0 ]
        then
            error "Error: there are running services"
            error "Try 'overnode down' to destroy the services"
            error "failure: prerequisites not satisfied"
            exit_error
        fi
    
        weave_socket=$(weave config)
        weave_run=${weave_socket#-H=unix://}
        weave_run=${weave_run%/weave.sock}

        warn "destroying agent"
        if [ -f ${volume}/proxy-config.yml ]
        then
            docker run --rm \
                -v ${volume}/proxy-config.yml:/docker-compose.yml \
                -v ${weave_run}:${weave_run}:ro \
                ${image_compose} ${weave_socket} --compatibility down --remove-orphans

            rm ${volume}/proxy-config.yml
        else
            println "agent is not running"
        fi
        
        warn "destroying weave"
        weave reset --force
        println "weave destroyed"
    fi

    if [ -f ${volume}/nodeid.txt ]
    then
        node_id=$(cat ${volume}/nodeid.txt)
        rm ${volume}/nodeid.txt
    else
        node_id=""
    fi

    if [[ ${purge} == "y" ]]
    then
        warn "destroying ${volume}"
        rm -Rf ${volume}
    fi

    println "[$node_id] Node reset"
}

node_peers=""
get_nodes() {
    node_peers=$(weave status peers | grep -v "-" | sed 's/^.*[:][0]\?[0]\?//' | sed 's/(.*//')
}

declare -A settings
read_settings_file()
{
    file="$1"
    while IFS="=" read -r key value; do
        case "$key" in
        '#'*) ;;
        *)
            if [[ ! -z "$key" ]]
            then
                pat="^[_0-9A-Za-z]+$"
                if [[ $key =~ $pat ]]
                then
                    settings[$key]="$value"
                else
                    error "Error: key '$key' contains not allowed characters"
                    error "Read overnode documentation for the details about configuration files."
                    error "failure: invalid configuration file"
                    exit_error
                fi
            fi
            ;;
        esac
    done < <(printf '%s\n' "$(cat $file)")
}

prepend_node_id_stdout() {
    node_id=$1
    while IFS= read -r line; do printf '[%s] %s\n' "$node_id" "$line"; done
}

prepend_node_id_stderr() {
    node_id=$1
    while IFS= read -r line; do printf "[%s] %s\n" "$node_id" "$line" >&2; done
}

overnode_client_container_id=""
cleanup_child() {
    if [ ! -z "$overnode_client_container_id" ]
    then
        docker kill $overnode_client_container_id > /dev/null 2>&1
    fi
}

login_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="u:,p:" --longoptions=username:,password:,password-stdin,server: --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    username=""
    password=""
    server=""
    while true; do
        case "$1" in
            -u|--username)
                username="--username $2"
                shift 2
                ;;
            -p|--password)
                password="--password $2"
                shift 2
                ;;
            --password-stdin)
                password="--password-stdin"
                shift
                ;;
            --server)
                server="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi

    docker login ${username} ${password} ${server}

    source_config=""
    if [ -f /etc/docker/config.json ]
    then
        if [ -f ${HOME}/.docker/config.json ]
        then
            home_config_stat=$(stat -c %y ${HOME}/.docker/config.json)
            etc_config_stat=$(stat -c %y /etc/docker/config.json)
            if [[ "$home_config_stat" > "$etc_config_stat" ]]
            then
                source_config="${HOME}/.docker/config.json"
            else
                source_config="/etc/docker/config.json"
            fi
        else
            source_config="/etc/docker/config.json"
        fi
    else
        if [ -f ${HOME}/.docker/config.json ]
        then
            source_config="${HOME}/.docker/config.json"
        else
            error "Error: failure to detect docker credentials either at '/etc/docker/config.json' or '${HOME}/.docker/config.json'"
            error "Try 'docker login' and copy docker/config.json file to the current directory manually."
            error "failure: prerequisites not satisfied"
            return 1
        fi
    fi
    
    cp $source_config ./docker-config.json
    warn "copied docker authentication token to ./docker-config.json"
}

compose_action() {
    command=$1
    shift
    
    getopt_allow_tailargs="n"
    getopt_args="nodes:"
    if [[ "${debug_on}" == "true" ]]
    then
        getopt_args="${getopt_args},help"
    fi
    
    opt_help=""
    opt_detach=""
    opt_quiet_pull=""
    opt_force_recreate=""
    opt_no_recreate=""
    opt_no_start=""
    opt_remove_orphans=""
    opt_remove_images=""
    opt_remove_volumes=""
    opt_timeout=""
    opt_no_color=""
    opt_follow=""
    opt_timestamps=""
    opt_tail=""
    case "$command" in
        up)
            getopt_args="${getopt_args},remove-orphans,attach,quiet-pull,force-recreate,no-recreate,no-start,timeout:"
            opt_detach="-d"
            ;;
        down)
            getopt_args="${getopt_args},remove-orphans,remove-images,remove-volumes,timeout:"
            ;;
        logs)
            getopt_allow_tailargs="y"
            getopt_args="${getopt_args},no-color,follow,timestamps,tail:"
            ;;
        top)
            getopt_allow_tailargs="y"
            ;;
        *)
            error "Error: internal error, $command"
            error "Please report this bug to https://github.com/avkonst/overnode/issues."
            return 1
            ;;
    esac
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=${getopt_args} --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    node_ids=""
    while true; do
        case "$1" in
            --nodes)
                node_ids=$2
                shift 2
                ;;
            --remove-orphans)
                opt_remove_orphans="--remove-orphans"
                shift
                ;;
            --remove-images)
                opt_remove_images="--rmi=all"
                shift
                ;;
            --remove-volumes)
                opt_remove_volumes="--volumes"
                shift
                ;;
            --attach)
                opt_detach=""
                shift
                ;;
            --quiet-pull)
                opt_quiet_pull="--quiet-pull"
                shift
                ;;
            --force-recreate)
                opt_force_recreate="--force-recreate"
                shift
                ;;
            --no-recreate)
                opt_no_recreate="--no-recreate"
                shift
                ;;
            --no-start)
                opt_detach=""
                opt_no_start="--no-start"
                shift
                ;;
            --timeout)
                pat="^[1-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    error "Error: parameter 'timeout' should be a number"
                    error "Try 'overnode help' for more information."
                    error "failure: invalid argument(s)"
                    return 1
                fi
                opt_timeout="--timeout $2"
                shift 2
                ;;
            --no-color)
                opt_no_color="--no-color"
                shift
                ;;
            --follow)
                opt_follow="--follow"
                shift
                ;;
            --timestamps)
                opt_timestamps="--timestamps"
                shift
                ;;
            --tail)
                pat="^[1-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    error "Error: parameter 'tail' should be a number"
                    error "Try 'overnode help' for more information."
                    error "failure: invalid argument(s)"
                    return 1
                fi
                opt_tail="--tail $2"
                shift 2
                ;;
            --help)
                opt_help="--help"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    required_services=""
    if [ ${getopt_allow_tailargs} == 'n' ]
    then
        if [ $# -ne 0 ]
        then
            error "Error: unexpected argument(s): $1"
            error "Try 'overnode help' for more information."
            error "failure: invalid argument(s)"
            exit_error
        fi
    else
        required_services=$@
    fi

    get_nodes

    node_ids=${node_ids//[,]/ }
    node_ids=${node_ids:-$node_peers}
    node_ids=$(echo "${node_ids}" | tr ' ' '\n' | sort | uniq | xargs) # remove duplicates
    
    for node_id in $node_ids
    do
        pat="^[1-9][0-9]?$"
        if [[ $node_id =~ $pat ]]
        then
            true
        else
            error "Error: parameter 'ids' contains not a number from 1 to 99"
            error "Try 'overnode help' for more information."
            error "failure: invalid argument(s)"
            return 1
        fi

        found=""
        for peer_id in $node_peers
        do
            if [[ "${node_id}" == "${peer_id}" ]]
            then
                found="y"
            fi
        done
        if [[ -z "$found" ]]
        then
            error "Error: node '${node_id}' is unknown"
            error "Try 'overnode status --peers --connections' for more information about cluster nodes."
            error "failure: invalid argument(s)"
        fi
    done
    
    if [ ! -f ./overnode.env ]
    then
        error "Error: configuration file ./overnode.env does not exist."
        error "Read overnode documentation for the details about configuration files."
        error "Try 'touch ./overnode.env' to create configuration for the cluster with no services."
        error "failure: prerequisites not satisfied"
        return 1
    fi

    read_settings_file ./overnode.env
    
    curdir="$(pwd -P)"
    [ -d ${curdir}/.overnode ] || mkdir ${curdir}/.overnode
    [ -f ${curdir}/.overnode/empty.yml ] || echo "version: \"3.7\"" > ${curdir}/.overnode/empty.yml
    [ -f ${curdir}/.overnode/sleep-infinity.sh ] || echo "while sleep 3600; do :; done" > ${curdir}/.overnode/sleep-infinity.sh

    docker_config_volume_arg=""
    if [ -f ${curdir}/docker-config.json ]
    then
        docker_config_volume_arg="-v ${curdir}/docker-config.json:/root/.docker/config.json -v ${curdir}/docker-config.json:/etc/docker/config.json"
    fi
    
    weave_socket=$(weave config)
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}

    session_id="$(date +%s)"
    trap "cleanup_child" EXIT
    cmd="docker ${weave_socket} run --rm \
        -d \
        --label mylabel \
        --name overnode-session-${session_id} \
        -v $curdir:/wdir \
        ${docker_config_volume_arg} \
        -w /wdir \
        ${image_compose} sh -e .overnode/sleep-infinity.sh"
    debug_cmd $cmd
    overnode_client_container_id=$($cmd)
    
    running_jobs=""
    all_configured_services=""
    declare -A matched_required_services_by_node
    for node_id in $node_ids
    do
        node_configs="-f .overnode/empty.yml"
        if exists $node_id in settings
        then
            for srv in ${settings[$node_id]}
            do
                node_configs="${node_configs} -f ${srv}"
            done
        fi
        
        matched_required_services=""
        if [ ! -z "$required_services" ]
        then
            cmd="docker exec \
                -w /wdir \
                --env NODE_ID=${node_id} \
                --env VOLUME=${volume} \
                ${overnode_client_container_id} docker-compose -H=10.47.240.${node_id}:2375 --compatibility ${node_configs} \
                config --services"
            debug_cmd $cmd
            configured_services=$($cmd 2> /dev/null)
            for required_srv in $required_services
            do
                for configured_srv in $configured_services
                do
                    all_configured_services="${all_configured_services} ${configured_srv}"
                    if [ ${required_srv} == ${configured_srv} ]
                    then
                        matched_required_services="${matched_required_services} ${required_srv}"
                    fi
                done
            done
        fi
        matched_required_services_by_node[$node_id]="${matched_required_services}"
    done
    
    for required_srv in $required_services
    do
        found=""
        for configured_srv in $all_configured_services
        do
            if [ ${required_srv} == ${configured_srv} ]
            then
                found="y"
            fi
        done
        
        if [ -z "${found}" ]
        then
            error "Error: no such service: ${required_srv}"
            # error "Try 'overnode help' for more information."
            error "failure: invalid argument(s)"
            return 1
        fi
    done
    
    for node_id in $node_ids
    do
        if [ -z "$required_services" ] || [ ! -z "${matched_required_services_by_node[$node_id]}" ]
        then
            # each client in the same container
            cmd="docker exec \
                -w /wdir \
                --env NODE_ID=${node_id} \
                --env VOLUME=${volume} \
                ${overnode_client_container_id} docker-compose -H=10.47.240.${node_id}:2375 --compatibility ${node_configs} \
                ${command} \
                ${opt_help} \
                ${opt_remove_orphans} \
                ${opt_remove_images} \
                ${opt_remove_volumes} \
                ${opt_quiet_pull} \
                ${opt_force_recreate} \
                ${opt_no_recreate} \
                ${opt_no_start} \
                ${opt_timeout} \
                ${opt_detach}\
                ${opt_no_color}\
                ${opt_follow}\
                ${opt_timestamps}\
                ${opt_tail}\
                ${matched_required_services_by_node[$node_id]} \
            "
            debug_cmd $cmd
            { $cmd 2>&3 | prepend_node_id_stdout $node_id; } 3>&1 1>&2 | prepend_node_id_stderr $node_id &
            running_jobs="${running_jobs} $!"
        fi
    done

    return_code=0
    for job_id in $running_jobs
    do
        wait $job_id
        if [ $? -ne 0 ]
        then
            return_code=1
        fi
    done
    return $return_code
}

env_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="i,q" --longoptions=id: --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    node_id=""
    inline=""
    quiet=""
    while true; do
        case "$1" in
            -i)
                inline="y"
                shift
                ;;
            -q)
                quiet="y"
                shift
                ;;
            --id)
                node_id=$2
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    
    if [ -z "$node_id" ]
    then
        error "Error: missing required parameter 'id'"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    
    pat="^[1-9][0-9]?$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        error "Error: parameter 'id' is not a number from 1 to 99"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    
    # print to stdout in any case
    if [ -z "${inline}" ]
    then
        println "export DOCKER_HOST=10.47.240.${node_id}:2375 ORIG_DOCKER_HOST=${DOCKER_HOST:-}"
    else
        println "-H=10.47.240.${node_id}:2375"
    fi

    if [ ! -z "${quiet}" ]
    then
        return 0
    fi

    get_nodes

    for peer_id in $node_peers
    do
        if [[ "${node_id}" == "${peer_id}" ]]
        then
            ip_addrs=$(weave dns-lookup overnode)
            for addr in $ip_addrs
            do
                if [[ "10.47.240.${node_id}" == $addr ]]
                then
                    return 0
                fi
            done
            
            error "Error: node '${node_id}' is unreachable"
            error "Try 'overnode dns-lookup overnode' for more information about reachable agents."
            error "Try 'overnode status --peers --connections' for more information about cluster nodes."
            error "failure: peer not is unreachable"
            return 1
        fi
    done
    
    error "Error: node '${node_id}' is unknown"
    error "Try 'overnode status --peers --ipam' for more information about cluster nodes."
    error "failure: invalid argument(s)"
    return 1
}

status_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=targets,peers,connections,dns,ipam,endpoints --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    any_arg="n"
    targets="n"
    peers="n"
    connections="n"
    dns="n"
    ipam="n"
    endpoints="n"
    while true; do
        case "$1" in
            --targets)
                any_arg="y"
                targets="y"
                shift
                ;;
            --peers)
                any_arg="y"
                peers="y"
                shift
                ;;
            --connections)
                any_arg="y"
                connections="y"
                shift
                ;;
            --dns)
                any_arg="y"
                dns="y"
                shift
                ;;
            --ipam)
                any_arg="y"
                ipam="y"
                shift
                ;;
            --endpoints)
                any_arg="y"
                endpoints="y"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi
    
    if [[ $any_arg == "n" ]]
    then
        warn "targets status"
        weave status targets

        warn "peers status"
        weave status peers

        warn "connections status"
        weave status connections

        warn "dns status"
        weave status dns

        warn "ipam status"
        weave status ipam

        warn "endpoints status"
        weave ps
    fi
    
    if [[ $targets == "y" ]]
    then
        warn "targets status"
        weave status targets
    fi

    if [[ $peers == "y" ]]
    then
        warn "peers status"
        weave status peers
    fi

    if [[ $connections == "y" ]]
    then
        warn "connections status"
        weave status connections
    fi

    if [[ $dns == "y" ]]
    then
        warn "dns status"
        weave status dns
    fi
    
    if [[ $ipam == "y" ]]
    then
        warn "ipam status"
        weave status ipam
    fi

    if [[ $endpoints == "y" ]]
    then
        warn "endpoints status"
        weave ps
    fi
}

inspect_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        return 1
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --)
                shift
                break
                ;;
            *)
                error "Error: internal error, $1"
                error "Please report this bug to https://github.com/avkonst/overnode/issues."
                return 1
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        error "Error: unexpected argument(s): $1"
        error "Try 'overnode help' for more information."
        error "failure: invalid argument(s)"
        exit_error
    fi

    weave report
}

expose_weave() {
    weave expose
}
expose_weave_silent() {
    expose_weave > /dev/null
}
expose_action() {
    shift
    ensure_no_args $@

    expose_weave
}

hide_weave(){
    weave hide
}
hide_weave_silent(){
    hide_weave > /dev/null
}
hide_action() {
    shift
    ensure_no_args $@

    hide_weave
}

dns_lookup_action() {
    shift
    ensure_one_arg $@
    
    weave dns-lookup $@
}

run() {
    if [[ -z "$@" ]]; then
        error "Error: action argument is expected"
        error "Try 'overnode help'."
        error "failure: invalid argument(s)"
        exit_error
    fi

    # handle debug argument
    if [[ $1 == "--debug" ]]; then
        debug_on="true"
        shift
    fi

    ensure_getopt

    #
    # execute the command
    #
    case $1 in
        help|--help|-help|-h)
            usage_no_exit
            exit_success
        ;;
        version|--version|-version)
            version_action $@ || exit_error
            exit_success
        ;;
        install)
            ensure_root
            install_action $@ || exit_error
            exit_success
        ;;
        upgrade)
            ensure_root
            upgrade_action $@ || exit_error
            exit_success
        ;;
        launch)
            ensure_root
            ensure_docker
            ensure_weave
            launch_action $@ || exit_error
            exit_success
        ;;
        reset)
            ensure_root
            ensure_docker
            ensure_weave
            reset_action $@ || exit_error
            exit_success
        ;;
        env)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            env_action $@ || exit_error
            exit_success
        ;;
        status)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            status_action $@ || exit_error
            exit_success
        ;;
        inspect)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            inspect_action $@ || exit_error
            exit_success
        ;;
        login)
            ensure_root
            ensure_docker
            login_action $@ || exit_error
            exit_success
        ;;
        up)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            compose_action $@ || exit_error
            exit_success
        ;;
        down)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            compose_action $@ || exit_error
            exit_success
        ;;
        logs)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            compose_action $@ || exit_error
            exit_success
        ;;
        top)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            compose_action $@ || exit_error
            exit_success
        ;;
        expose)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            expose_action $@ || exit_error
            exit_success
        ;;
        hide)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            hide_action $@ || exit_error
            exit_success
        ;;
        dns-lookup)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            dns_lookup_action $@ || exit_error
            exit_success
        ;;
        "")
            error "Error: action argument is required"
            error "Try 'overnode help' for more information."
            error "failure: invalid argument(s)"
            exit_error
        ;;
        *)
            error "Error: unknown action '$1'"
            error "Try 'overnode help' for more information."
            error "failure: invalid argument(s)"
            exit_error
        ;;
    esac
}

run $@ # wrap in a function to prevent partial download
