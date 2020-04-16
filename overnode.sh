#!/bin/bash

set -e
set -o errexit -o pipefail -o noclobber -o nounset

version_docker=19.03.8
version_compose=1.25.4
version_weave=2.6.2
version_proxy=1.7.3.4-r0
version_system=0.8.9

provider_proxy="alpine/socat"
provider_compose="docker/compose"

image_proxy="${provider_proxy}:${version_proxy}"
image_compose="${provider_compose}:${version_compose}"

log="[overnode]"
debug_on="false"

green_c='\033[0;32m'
green_light_c='\033[1;32m'
red_c='\033[0;31m'
red_light_c='\033[1;31m'
cyan_c='\033[0;36m'
cyan_light_c='\033[1;36m'
yellow_c='\033[0;33m'
yellow_light_c='\033[1;33m'
gray_c='\033[1;30m'
gray_light_c='\033[1;30m'
no_c='\033[0;37m'
no_light_c='\033[1;37m'
current_c="${no_c}"
set_console_color() {
    current_c=$1
    printf "$1" >&2
}
set_console_normal() {
    current_c=$no_c
    printf "${no_c}" >&2
}
trap set_console_normal EXIT

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo -e "${gray_light_c}$log $@${current_c}")
    fi
}
debug_cmd() {
    debug "${yellow_c}>>>${current_c} $@" 
}
info() {
    (>&2 echo -e "$log $@${current_c}")
}
info_progress() {
    (>&2 echo -e "${cyan_light_c}$log $@${current_c}")
}
warn() {
    (>&2 echo -e "${yellow_light_c}$log $@${current_c}")
}
error() {
    (>&2 echo -e "${red_light_c}$log $@${current_c}")
}

println() {
    echo -e "$@"
}

prepend_stdout() {
    suffix=$1
    while IFS= read -r line; do echo -e "$suffix $line"; done
}
prepend_stderr() {
    suffix=$1
    while IFS= read -r line; do echo -e "$suffix $line" >&2; done
}

run_cmd_wrap() {
    debug_cmd $@
    progress_suffix="         |"
    { { $@; } 2>&3 | prepend_stdout "${progress_suffix}"; } 3>&1 1>&2 | prepend_stderr "${progress_suffix}"
}

exit_success() {
    debug "${green_light_c}[action completed]${current_c}"
    exit 0
}

exit_error() {
    if [ ! -z "${1:-}" ]
    then
        error "Error: ${1:-}"
        shift
    fi
    for line in "$@"
    do
        info $line
    done
    error "[action aborted]"
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

current_command=""

ensure_no_args() {
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [[ ! -z "$@" ]]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
}

ensure_one_arg() {
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 1 ]
    then
        exit_error "expected argument(s)" "Run '> overnode ${current_command} --help' for more information"
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

ensure_root() {
    if [ "$(id -u)" -ne "0" ]
    then
        exit_error "root privileges required" "Try '> sudo overnode $@'"
    fi
}

ensure_getopt() {
    # -allow a command to fail with !’s side effect on errexit
    # -use return value from ${PIPESTATUS[0]}, because ! hosed $?
    ! getopt --test > /dev/null 
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        exit_error "requires: getopt, found: none" "Try installing getopt utility using operation system package manager"
    fi
}

ensure_docker() {
    if [ "$(which docker | wc -l)" -eq "0" ]
    then
        exit_error "requires: docker, found: none" "Run '> overnode install' to install docker"
    fi
}

ensure_weave() {
    if [ "$(which weave | wc -l)" -eq "0" ]
    then
        exit_error "requires: weave, found: none" "Run '> overnode install' to install weave"
    fi
}

ensure_weave_running() {
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        exit_error "weave is not running" "Run '> overnode launch' to start the node"
    fi    
}

ensure_overnode_running() {
    if [ ! -f /etc/overnode/id ]
    then
        exit_error "overnode is not running" "Run '> overnode launch' to start the node"
    fi    
}

install_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=f --longoptions=force --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done

    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $1" "Run '> overnode ${current_command} --help' for more information"
    fi

    cmd="mkdir /etc/overnode"
    [ -d /etc/overnode ] || run_cmd_wrap $cmd || {
        exit_error "failure to create directory: /etc/overnode" "Failed command:" "> $cmd"
    }
    if [ ! -f /etc/overnode/system.env ]
    then
        # running installation first time
        if [ "$(which docker | wc -l)" -ne "0" ]
        then
            install_docker="false"
        fi
        echo "install_docker=${install_docker:-true}" > /etc/overnode/system.env
    fi
    
    eval $(cat /etc/overnode/system.env) # will source install_docker flag

    installed_something="n"
    info_progress "Installing docker ..."
    if [[ ${install_docker} == "true" ]] && [[ "$(which docker | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        cmd="wget -q --no-cache -O /tmp/get.docker.sh https://get.docker.com"
        run_cmd_wrap $cmd || {
            exit_error "failure to download file: https://get.docker.com" "Failed command:" "> ${cmd}"
        }
        export VERSION=${version_docker}
        cmd="sh /tmp/get.docker.sh"
        run_cmd_wrap $cmd || {
            exit_error "failure to install docker" "Failed command:" "> ${cmd}"
        }
        set_console_normal
        installed_something="y"
        info_progress "=> done"
    else
        info_progress "=> already installed"
    fi

    info_progress "Installing weave ..."
    if [ "$(which weave | wc -l)" -eq "0" ]
    then
        set_console_color "${gray_c}"
        cmd="wget -q --no-cache -O /usr/local/bin/weave https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave"
        run_cmd_wrap $cmd || {
            exit_error "failure to download file: https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave" "Failed command:" "> ${cmd}"
        }
        run_cmd_wrap chmod a+x /usr/local/bin/weave
        cmd="weave setup"
        run_cmd_wrap $cmd || {
            exit_error "failure to setup weave" "Failed command:" "> ${cmd}"
        }
        set_console_normal
        installed_something="y"
    else
        if [[ ${force} == "y" ]]
        then
            set_console_color "${gray_c}"
            cmd="rm /tmp/weave"
            [ ! -f /tmp/weave ] || run_cmd_wrap $cmd || {
                exit_error "failure to delete file: /tmp/weave" "Failed command:" "> ${cmd}"
            }
            cmd="wget -q --no-cache -O /tmp/weave https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave"
            run_cmd_wrap $cmd || {
                exit_error "failure to download file: https://github.com/weaveworks/weave/releases/download/v${version_weave}/weave" "Failed command:" "> ${cmd}"
            }
            run_cmd_wrap chmod a+x /tmp/weave
            cmd="/tmp/weave setup"
            run_cmd_wrap $cmd || {
                exit_error "failure to setup weave" "Failed command:" "> ${cmd}"
            }
            set_console_normal

            tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
            if [ $weave_running -eq 0 ]
            then
                set_console_color "${gray_c}"
                info_progress "Restarting weave ..."
                cmd="weave stop"
                run_cmd_wrap $cmd || {
                    exit_error "failure to stop weave" "Failed command:" "> ${cmd}"
                }
                run_cmd_wrap cp /tmp/weave /usr/local/bin/weave
                cmd="weave launch --resume" # https://github.com/weaveworks/weave/issues/3050#issuecomment-326932723
                run_cmd_wrap $cmd || {
                    exit_error "failure to start weave" "Failed command:" "> ${cmd}"
                }
                set_console_normal
            else
                run_cmd_wrap cp /tmp/weave /usr/local/bin/weave
            fi
            installed_something="y"
            info_progress "=> weave installation complete"
        else
            info_progress "=> weave is already installed"
        fi
    fi
    
    info_progress "Installing compose ..."
    if [[ "$(docker images | grep ${provider_compose} | grep ${version_compose} | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        cmd="docker pull ${image_compose}"
        run_cmd_wrap $cmd || {
            exit_error "failure to pull ${image_compose} image" "Failed command:" "> ${cmd}"
        }
        set_console_normal
        installed_something="y"
        info_progress "=> compose installation complete"
    else
        info_progress "=> compose is already installed"
    fi
    
    info_progress "Installing agent ..."
    if [[ "$(docker images | grep ${provider_proxy} | grep ${version_proxy} | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        cmd="docker pull ${image_proxy}"
        run_cmd_wrap $cmd || {
            exit_error "failure to pull ${image_proxy} image" "Failed command:" "> ${cmd}"
        }
        set_console_normal
        installed_something="y"
        info_progress "=> agent installation complete"
    else
        info_progress "=> agent is already installed"
    fi
    
    if [ "${installed_something}" == "n" ]
    then
        info ""
        warn "Everything was already installed."
        info "> run 'overnode upgrade' to upgrade."
        info "> run 'overnode install --force' to re-install."
    fi
    
    println "[-] Installed"
}

upgrade_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="version:" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done

    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi

    [ ! -f /tmp/install.sh ] || rm /tmp/install.sh
    cmd="wget -q --no-cache -O /tmp/install.sh https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh"
    run_cmd_wrap $cmd || {
        exit_error "failure to download file: https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh" "Failed command:" "> $cmd"
    }
    chmod a+x /tmp/install.sh

    cmd="/tmp/install.sh --force"
    run_cmd_wrap $cmd || {
        exit_error "upgrade unsuccessful: /tmp/install.sh script exited abnormally" "Failed command:" "> $cmd"
    }
}

create_main_config() {
    image_proxy=$1
    node_id=$2
    weave_run=$3
    
    [ -f /etc/overnode/system.yml ] && rm /etc/overnode/system.yml
    
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
            - /etc/overnode/volume:/overnode.etc
            - overnode:/overnode
            - ${weave_run}:/var/run/weave:ro
        restart: always
        network_mode: bridge
        command: TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/weave/weave.sock
volumes:
    overnode:
        driver: local
        name: overnode
""" > /etc/overnode/system.yml
}

launch_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=token:,id: --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done

    if [ -z "$token" ]
    then
        exit_error "missing required parameter: token" "Run '> overnode ${current_command} --help' for more information"
    fi

    if [ -z "$node_id" ]
    then
        exit_error "missing required parameter: id" "Run '> overnode ${current_command} --help' for more information"
    fi

    pat="^[1-9][0-9]?$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        exit_error "invalid argument: id, required: number [1-99], received: $node_id" "Run '> overnode ${current_command} --help' for more information"
    fi

    info_progress "Launching weave ..."
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
            exit_error "weave container terminated abnormally" "Run '> docker logs ${cid}' for more information"
        fi
        info_progress "=> weave is running: $output"
    else
        info_progress "=> weave is already running"
    fi

    [ -d /etc/overnode ] || mkdir /etc/overnode

    if [ -f /etc/overnode/id ]
    then
        node_id_existing=$(cat /etc/overnode/id)
        if [[ "${node_id}" != "${node_id_existing}" ]]
        then
            exit_error "invalid argument: id, required: ${node_id_existing} (existing), received: $node_id" \
                "Run '> overnode ${current_command} --help' for more information" \
                "Run '> overnode reset' to destroy the existing node"
        fi
    else
        echo ${node_id} > /etc/overnode/id
    fi

    info_progress "Launching agent ..."
    weave_socket=$(weave config)
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}

    create_main_config ${image_proxy} ${node_id} ${weave_run}
    cmd="docker run --rm \
        -v /etc/overnode/system.yml:/docker-compose.yml \
        -v ${weave_run}:${weave_run}:ro \
        ${image_compose} ${weave_socket} --compatibility up -d --remove-orphans"
    run_cmd_wrap $cmd && info_progress "=> done" || {
        exit_error "failure to run docker container" "Failed command:" "> $cmd"
    }
        
    [ -d /tmp/.overnode ] || mkdir /tmp/.overnode
    [ -f /tmp/.overnode/system.yml ] || printf """
version: '3.7'
""" > /tmp/.overnode/system.yml
    [ -f /tmp/.overnode/sleep-infinity.sh ] || printf """
echo started;
while sleep 3600; do :; done
""" > /tmp/.overnode/sleep-infinity.sh
    [ -f /tmp/.overnode/sync-etc.sh ] || printf '''
set -e

source_dir=$1
target_dir=$2
mount_dir=$3
dry_run=""

md5compare() {
    sum1=$(md5sum $1 | cut -d " " -f 1)
    sum2=$(md5sum $2 | cut -d " " -f 1)
    if test "${sum1}" = "${sum2}"
    then
        return 0;
    else
        return 1;
    fi
}

for curr_file in $(find ${source_dir} | sed -n "s|^${source_dir}/||p")
do
    if [ -f "${source_dir}/${curr_file}" ]
    then
        if [ -f "${target_dir}/${curr_file}" ]
        then
            md5compare ${source_dir}/${curr_file} "${target_dir}/${curr_file}" || {
                echo "Recreating ${mount_dir}/${curr_file} ..."
                ${dry_run} cp ${source_dir}/${curr_file} "${target_dir}/${curr_file}"
            }
        elif [ -d "${target_dir}/${curr_file}" ]
        then
            echo "Recreating ${mount_dir}/${curr_file} ..."
            ${dry_run} rm -Rf "${target_dir}/${curr_file}"
            ${dry_run} cp "${source_dir}/${curr_file}" "${target_dir}/${curr_file}"
        else
            echo "Creating ${mount_dir}/${curr_file} ..."
            ${dry_run} cp "${source_dir}/${curr_file}" "${target_dir}/${curr_file}"
        fi
    else # directory
        if [ -f "${target_dir}/${curr_file}" ]
        then
            echo "Recreating ${mount_dir}/${curr_file} ..."
            ${dry_run} rm -Rf "${target_dir}/${curr_file}"
            ${dry_run} cp -r "${source_dir}/${curr_file}" "${target_dir}/${curr_file}"
        elif [ -d "${target_dir}/${curr_file}" ]
        then
            true # do nothing
        else
            echo "Creating ${mount_dir}/${curr_file} ..."
            ${dry_run} cp -r "${source_dir}/${curr_file}" "${target_dir}/${curr_file}"
        fi
    fi
done

for curr_file in $(find ${target_dir} | sed -n "s|^${target_dir}/||p")
do
    if [ -f "${source_dir}/${curr_file}" -o -d "${source_dir}/${curr_file}" ]
    then
        true
    else
        echo "Deleting ${mount_dir}/${curr_file} ..."
        ${dry_run} rm -Rf "${target_dir}/${curr_file}"
    fi
done

rm -Rf "${source_dir}"
''' > /tmp/.overnode/sync-etc.sh
        
    docker cp /tmp/.overnode/. overnode:/overnode
    rm -Rf /tmp/.overnode

    println "[$node_id] Node launched"
}

resume_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        info_progress "Resuming weave ..."
        docker start weave > /dev/null
        info_progress "=> weave resumed"
    else
        info_progress "Resuming weave ..."
        info_progress "=> weave is already running"
    fi
    
    info_progress "Resuming agent ..."
    if [ "$(docker ps --filter name=overnode -q)" == "" ]
    then
        docker start overnode > /dev/null
        info_progress "=> agent resumed"
    else
        info_progress "=> agent is already running"
    fi

    node_id=$(cat /etc/overnode/id)
    println "[$node_id] Node resumed"
}

reset_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        info_progress "Destroying agent ..."
        if [ -f /etc/overnode/system.yml ]
        then
            docker run --rm \
                -v /etc/overnode/system.yml:/docker-compose.yml \
                -v /var/run/docker.sock:/var/run/docker.sock \
                ${image_compose} --compatibility down --remove-orphans --volumes

            rm /etc/overnode/system.yml
            info_progress "=> agent destruction complete"
        else
            info_progress "=> agent is already destroyed"
        fi

        info_progress "Destroying weave ..."
        weave reset --force >/dev/null 2>&1
        info_progress "=> weave is already destroyed"
    else
        if [ $(weave ps | grep -v expose | grep -v 10.47.240 | wc -l) -ne 0 ]
        then
            exit_error "there are running services" "Run '> overnode down' to destroy the services"
        fi
    
        weave_socket=$(weave config)
        weave_run=${weave_socket#-H=unix://}
        weave_run=${weave_run%/weave.sock}

        info_progress "Destroying agent ..."
        if [ -f /etc/overnode/system.yml ]
        then
            docker run --rm \
                -v /etc/overnode/system.yml:/docker-compose.yml \
                -v ${weave_run}:${weave_run}:ro \
                ${image_compose} ${weave_socket} --compatibility down --remove-orphans --volumes

            rm /etc/overnode/system.yml
            info_progress "=> agent destruction complete"
        else
            info_progress "=> agent is already destroyed"
        fi
        
        info_progress "Destroying weave ..."
        weave reset --force
        info_progress "=> weave destruction complete"
    fi

    if [ -f /etc/overnode/id ]
    then
        node_id=$(cat /etc/overnode/id)
        rm /etc/overnode/id
    else
        node_id="-"
    fi

    println "[$node_id] Node reset"
}

connect_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="replace" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    replace=""
    while true; do
        case "$1" in
            --replace)
                replace="--replace"
                shift
                break
                ;;
            --)
                shift
                break
                ;;
            *)
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -eq 0 ]
    then
        exit_error "expected argument(s)" "Run '> overnode ${current_command} --help' for more information"
    fi

    weave connect ${replace} $@
}

forget_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -eq 0 ]
    then
        exit_error "expected argument(s)" "Run '> overnode ${current_command} --help' for more information"
    fi

    weave forget $@
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
                    exit_error "invalid configuration file: key '$key' contains not allowed characters" "Check out documentation about configuration file format"
                fi
            fi
            ;;
        esac
    done < <(printf '%s\n' "$(cat $file)")
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
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
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
            exit_error "failure to locate docker/config.json file, tried: /etc/docker/config.json and ${HOME}/.docker/config.json" \
                "Run '> docker login' and copy docker/config.json file to the current directory manually"
        fi
    fi
    
    cp $source_config ./docker-config.json
    println "[*] Authentication token saved: ./docker-config.json"
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
    
    opt_detach=""
    opt_collected=""
    case "$command" in
        config)
            getopt_args="${getopt_args},resolve-image-digests,no-interpolate,quiet,services,volumes,hash:"
            ;;
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
        events)
            getopt_args="${getopt_args},json"
            getopt_allow_tailargs="y"
            ;;
        kill)
            getopt_args="${getopt_args},signal:"
            getopt_allow_tailargs="y"
            ;;
        ps)
            getopt_args="${getopt_args},quiet,services,filter:,all"
            getopt_allow_tailargs="y"
            ;;
        pull)
            getopt_args="${getopt_args},quiet,include-deps,no-parallel,ignore-pull-failures"
            getopt_allow_tailargs="y"
            ;;
        push)
            getopt_args="${getopt_args},ignore-push-failures"
            getopt_allow_tailargs="y"
            ;;
        restart)
            getopt_args="${getopt_args},timeout:"
            getopt_allow_tailargs="y"
            ;;
        rm)
            getopt_args="${getopt_args},force,stop,remove-volumes"
            getopt_allow_tailargs="y"
            ;;
        stop)
            getopt_args="${getopt_args},timeout:"
            getopt_allow_tailargs="y"
            ;;
        top|pause|unpause|start)
            getopt_allow_tailargs="y"
            ;;
        *)
            exit_error "internal: $command" "Please report this bug to https://github.com/avkonst/overnode/issues"
            ;;
    esac
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=${getopt_args} --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
            --remove-images)
                opt_collected="${opt_collected} --rmi all"
                shift
                ;;
            --remove-volumes)
                if [ $command == "down" ]
                then
                    opt_collected="${opt_collected} --volumes"
                else # command == rm
                    opt_collected="${opt_collected} -v"
                fi
                shift
                ;;
            --attach)
                opt_detach=""
                shift
                ;;
            --timeout)
                pat="^[1-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    exit_error "invalid argument: timeout, required: number, received: $2" "Run '> overnode ${current_command} --help' for more information"
                fi
                opt_collected="${opt_collected} --timeout $2"
                shift 2
                ;;
            --tail)
                pat="^[1-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    exit_error "invalid argument: tail, required: number, received: $2" "Run '> overnode ${current_command} --help' for more information"
                fi
                opt_collected="${opt_collected} --tail $2"
                shift 2
                ;;
            --hash)
                opt_collected="--hash $2"
                shift 2
                ;;
            --signal)
                opt_collected="-s $2"
                shift 2
                ;;
            --filter)
                opt_collected="--filter $2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                opt_collected="${opt_collected} $1"
                shift
                ;;
        esac
    done
    
    required_services=""
    if [ ${getopt_allow_tailargs} == 'n' ]
    then
        if [ $# -ne 0 ]
        then
            exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
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
            exit_error "invalid argument: nodes, required: comma separated numbers [0-99], received: ${node_id}" "Run '> overnode ${current_command} --help' for more information"
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
            exit_error "invalid argument: nodes, unknown node: ${node_id}" \
                "Run 'overnode status --peers --connections' to list available nodes and connections."
        fi
    done
    
    if [ ! -f ./overnode.env ]
    then
        exit_error "configuration file does not exist: ./overnode.env" \
            "Run 'touch ./overnode.env' to create empty configuration"
    fi

    read_settings_file ./overnode.env
    
    curdir="$(pwd -P)"

    docker_config_volume_arg=""
    if [ -f ${curdir}/docker-config.json ]
    then
        docker_config_volume_arg="-v ${curdir}/docker-config.json:/root/.docker/config.json -v ${curdir}/docker-config.json:/etc/docker/config.json"
    fi
    
    weave_socket=$(weave config)
    weave_run=${weave_socket#-H=unix://}
    weave_run=${weave_run%/weave.sock}
    docker_path=$(which docker)

    session_id="$(date +%s)"
    trap "cleanup_child" EXIT
    cmd="docker ${weave_socket} run --rm \
        -d \
        --label mylabel \
        --name overnode-session-${session_id} \
        -v $curdir:/wdir \
        -v overnode:/overnode \
        -v ${docker_path}:${docker_path} \
        ${docker_config_volume_arg} \
        -w /wdir \
        ${image_compose} sh -e /overnode/sleep-infinity.sh"
    debug_cmd $cmd
    overnode_client_container_id=$($cmd)
    
    running_jobs=""
    all_configured_services=""
    declare -A matched_required_services_by_node
    for node_id in $node_ids
    do
        node_configs="-f /overnode/system.yml"
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
                --env OVERNODE_ID=${node_id} \
                --env OVERNODE_ETC=/etc/overnode/volume \
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
            exit_error "invalid argument: ${required_srv}, required: known service name" \
                "Run '> overnode config --services' to list known services"
        fi
    done
    
    for node_id in $node_ids
    do
        if [ -z "$required_services" ] || [ ! -z "${matched_required_services_by_node[$node_id]}" ]
        then
            
            if [ ${command} == "up" ]
            then
                cp_cmd="docker exec \
                    ${overnode_client_container_id} docker -H=10.47.240.${node_id}:2375 \
                    cp ./overnode.etc/. overnode:/tmp/overnode.etc \
                "
                debug_cmd $cp_cmd

                rm_cmd="docker exec \
                    ${overnode_client_container_id} docker -H=10.47.240.${node_id}:2375 \
                    exec -w /overnode.etc overnode sh /overnode/sync-etc.sh /tmp/overnode.etc /overnode.etc /etc/overnode/volume \
                "
                debug_cmd $rm_cmd
            fi
            
            # each client in the same container
            cmd="docker exec \
                -w /wdir \
                --env OVERNODE_ID=${node_id} \
                --env OVERNODE_ETC=/etc/overnode/volume \
                ${overnode_client_container_id} docker-compose -H=10.47.240.${node_id}:2375 \
                --compatibility \
                ${node_configs} \
                ${command} \
                ${opt_collected} \
                ${opt_detach}\
                ${matched_required_services_by_node[$node_id]} \
            "
            debug_cmd $cmd
            { { { ${cp_cmd:-true} && ${rm_cmd:-true}; } && $cmd; } 2>&3 | prepend_stdout "[$node_id]"; } 3>&1 1>&2 | prepend_stderr "[$node_id]" &
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
    
    exit $return_code
}

env_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="i,q" --longoptions=id: --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    if [ -z "$node_id" ]
    then
        exit_error "missing required parameter: id" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    pat="^[1-9][0-9]?$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        exit_error "invalid argument: id, required number [1-99], received: $node_id" "Run '> overnode ${current_command} --help' for more information"
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
        exit_success
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
                    exit_success
                fi
            done
            
            exit_error "node is unreachable: ${node_id}" \
                "Run '> overnode dns-lookup overnode' to inspect agent's dns records" \
                "Run '> overnode status --peers --connections' to list available nodes and connections"
        fi
    done
    
    exit_error "node is unknown: ${node_id}" "Run '> overnode status --peers' to list available nodes"
}

status_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions=targets,peers,connections,dns,ipam,endpoints --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    if [[ $any_arg == "n" ]]
    then
        info_progress "targets status:"
        weave status targets

        info_progress "peers status:"
        weave status peers

        info_progress "connections status:"
        weave status connections

        info_progress "dns status:"
        weave status dns

        info_progress "ipam status:"
        weave status ipam

        info_progress "endpoints status:"
        weave ps
    fi
    
    if [[ $targets == "y" ]]
    then
        info_progress "targets status:"
        weave status targets
    fi

    if [[ $peers == "y" ]]
    then
        info_progress "peers status:"
        weave status peers
    fi

    if [[ $connections == "y" ]]
    then
        info_progress "connections status:"
        weave status connections
    fi

    if [[ $dns == "y" ]]
    then
        info_progress "dns status:"
        weave status dns
    fi
    
    if [[ $ipam == "y" ]]
    then
        info_progress "ipam status:"
        weave status ipam
    fi

    if [[ $endpoints == "y" ]]
    then
        info_progress "endpoints status:"
        weave ps
    fi
}

inspect_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
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
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
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

# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

dns_addremove_action() {
    command=$1
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="" --longoptions="ips:,name:" --name "[overnode]" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    ips=""
    name=""
    while true; do
        case "$1" in
            --ips)
                ips="${2//[,]/ }"
                shift 2
                ;;
            --name)
                if [ "$2" == *.overnode.local ]
                then
                    name=$2
                else
                    name="$2.overnode.local"
                fi
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                exit_error "internal: $1" "Please report this bug to https://github.com/avkonst/overnode/issues"
                ;;
        esac
    done
    
    for ip in $ips
    do
        if ! valid_ip $ip
        then
            exit_error "invalid argument: ips, required: ip address, received: $ip" "Run '> overnode ${current_command} --help' for more information"
        fi
    done
    
    if [ $# -ne 0 ]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    weave ${command} ${ips} -h ${name}
}

dns_lookup_action() {
    shift
    ensure_one_arg $@
    
    weave dns-lookup $@
}

run() {
    if [[ -z "$@" ]]; then
        exit_error "expected argument(s)" "Run '> overnode --help' for more information"
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
    current_command=$1
    case $1 in
        help|--help|-help|-h)
            usage_no_exit
            exit_success
        ;;
        version|--version|-version)
            version_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        install)
            ensure_root
            install_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        upgrade)
            ensure_root
            upgrade_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        launch)
            ensure_root
            ensure_docker
            ensure_weave
            launch_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        resume)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_overnode_running
            resume_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        reset)
            ensure_root
            ensure_docker
            ensure_weave
            reset_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        connect)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_overnode_running
            connect_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        forget)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_overnode_running
            forget_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        env)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            env_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        status)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            status_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        inspect)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            inspect_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        login)
            ensure_root
            ensure_docker
            login_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        config|up|down|logs|top|events|kill|pause|unpause|ps|pull|push|restart|rm|start|stop)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            compose_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        expose)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            expose_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        hide)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            hide_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        dns-add|dns-remove)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            dns_addremove_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        dns-lookup)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            dns_lookup_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        "")
            exit_error "expected argument(s)" "Run '> overnode --help' for more information"
        ;;
        *)
            exit_error "unexpected argument: $1" "Run '> overnode --help' for more information"
        ;;
    esac
}

run $@ # wrap in a function to prevent partial download
