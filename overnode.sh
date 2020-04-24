#!/bin/bash

set -e
set -o errexit -o pipefail -o noclobber -o nounset

version_docker=19.03.8
version_compose=1.25.4
version_weave=2.6.2
version_proxy=1.7.3.4-r0
version_git=latest
version_system=0.9.3

provider_proxy="alpine/socat"
provider_git="alpine/git"
provider_compose="docker/compose"

image_proxy="${provider_proxy}:${version_proxy}"
image_git="${provider_git}:${version_git}"
image_compose="${provider_compose}:${version_compose}"

log="[overnode]"
debug_on="false"

green_c='\033[1;32m'
red_c='\033[1;31m'
cyan_c='\033[1;36m'
yellow_c='\033[1;33m'
gray_c='\033[1;30m'
no_c='\033[0;37m'
current_c="${no_c}"
no_color_mode=""
set_console_nocolor() {
    green_c=''
    red_c=''
    cyan_c=''
    yellow_c=''
    gray_c=''
    no_c=''
    current_c=""
    no_color_mode="y"
}
set_console_color() {
    current_c=${1:-}
    printf "$current_c" >&2
}
set_console_normal() {
    if [ "$current_c" != "${no_c}" ]
    then
        current_c=$no_c
        printf "${no_c}" >&2
    fi
}
trap set_console_normal EXIT

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo -e "${gray_c}$log $@${current_c}")
    fi
}
debug_cmd() {
    debug "${yellow_c}>>>${gray_c} $@" 
}
info() {
    (>&2 echo -e "$log $@${current_c}")
}
info_no_prefix() {
    (>&2 echo -e "$@${current_c}")
}
info_progress() {
    (>&2 echo -e "${cyan_c}$log $@${current_c}")
}
warn() {
    (>&2 echo -e "${yellow_c}$log $@${current_c}")
}
error() {
    (>&2 echo -e "${red_c}$log $@${current_c}")
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
    $@
}

exit_success() {
    debug "${green_c}[action completed]${current_c}"
    exit 0
}

exit_error() {
    if [ ! -z "${1:-}" ]
    then
        error "Error: ${1:-}"
    fi
    shift
    set_console_normal
    
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

line="${gray_c}----------------------------------------------------------------------------${no_c}"
usage_no_exit() {

printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}<action> [OPTION] ...${no_c}

  Actions:   Description:
  ${line}
  ${cyan_c}install${no_c}    Install overnode and the required dependencies.
  ${cyan_c}upgrade${no_c}    Download and install newer version of overnode and dependencies.
  ${line}
  ${cyan_c}launch${no_c}     Launch the node and / or join a cluster.
  ${cyan_c}reset${no_c}      Leave a cluster and destroy the node.
  ${cyan_c}resume${no_c}     Restart previously launched node if it is not running.
  ${line}
  ${cyan_c}connect${no_c}    Add an additional target peer node to connect to.
  ${cyan_c}forget${no_c}     Remove existing target peer node.
  ${line}
  ${cyan_c}expose${no_c}     Establish connectivity between the host and the cluster.
  ${cyan_c}hide${no_c}       Destroy connectivity between the host and the cluster.
  ${cyan_c}env${no_c}        Print remote node connection string for docker client.
  ${line}
  ${cyan_c}dns-lookup${no_c} Lookup DNS entries of a cluster.
  ${cyan_c}dns-add${no_c}    Add extra DNS entries.
  ${cyan_c}dns-remove${no_c} Remove extra DNS entries.
  ${line}
  ${cyan_c}login${no_c}      Provide credentials to pull images from private repositories.
  ${cyan_c}logout${no_c}     Remove credentials to pull images from private repositories.
  ${line}
  ${cyan_c}init${no_c}       Download configs for services from peer nodes or external repos.
  ${cyan_c}up${no_c}         Build, (re)create, and start containers for services.
  ${cyan_c}down${no_c}       Stop and remove containers, networks, volumes, and images.
  ${line}
  ${cyan_c}start${no_c}      Start existing containers of services.
  ${cyan_c}stop${no_c}       Stop running containers without removing them. 
  ${cyan_c}restart${no_c}    Restart all stopped and running services.
  ${cyan_c}pause${no_c}      Pause running containers of services.
  ${cyan_c}unpause${no_c}    Unpause paused containers of services.
  ${cyan_c}kill${no_c}       Force running containers to stop by sending a signal.
  ${cyan_c}rm${no_c}         Remove stopped containers of services.
  ${cyan_c}pull${no_c}       Pull images associated with services.
  ${cyan_c}push${no_c}       Push images for services to their respective repositories.
  ${line}
  ${cyan_c}ps${no_c}         List containers and states of services.
  ${cyan_c}log${no_c}        Display log output from services.
  ${cyan_c}top${no_c}        Display the running processes for containers of services.
  ${cyan_c}events${no_c}     Stream events for containers of services in the cluster.
  ${cyan_c}config${no_c}     Validate and view the configuration for services.
  ${cyan_c}status${no_c}     View the state of the node, connections, dns, ipam, endpoints.
  ${cyan_c}inspect${no_c}    View and inspect the state of the node in full details.
  ${line}
  ${cyan_c}help${no_c}       Print this help information.
  ${cyan_c}version${no_c}    Print version information.
  ${line}
"""
}

current_command=""

ensure_no_args() {
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
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
    
    if [[ ! -z "$@" ]]
    then
        exit_error "unexpected argument(s): $@" "Run '> overnode ${current_command} --help' for more information"
    fi
}

version_action() {
    shift
    ensure_no_args $@
    
    println "Overnode - Multi-node Docker containers orchestration."
    println "    version: $version_system"
    println "    docker:  $version_docker [required], $(docker version 2>&1 | grep Version | head -n1 | awk '{print $2}') [installed]"
    println "    weave:   $version_weave [required], $(weave version 2>&1 | grep script | head -n1 | awk '{print $3}') [installed]"
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
        exit_error "weave is not running" "Run '> overnode launch' to start the node" "Run '> overnode resume' to restart the node"
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
    ! PARSED=$(getopt --options=f,h --longoptions=force,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    force="n"
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}install [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}-f|--force${no_c} Force to re-install, if already installed.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
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
        if [ "$(which weave | wc -l)" -ne "0" ]
        then
            install_weave="false"
        fi
        echo "install_weave=${install_weave:-true}" >> /etc/overnode/system.env
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
    if [[ ${install_weave} == "true" ]] && [[ "$(which weave | wc -l)" -eq "0" || ${force} == "y" ]]
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
            info_progress "=> done"
        else
            info_progress "=> already installed"
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
        info_progress "=> done"
    else
        info_progress "=> already installed"
    fi

    info_progress "Installing git ..."
    if [[ "$(docker images | grep ${provider_git} | grep ${version_git} | wc -l)" -eq "0" || ${force} == "y" ]]
    then
        set_console_color "${gray_c}"
        cmd="docker pull ${image_git}"
        run_cmd_wrap $cmd || {
            exit_error "failure to pull ${image_git} image" "Failed command:" "> ${cmd}"
        }
        set_console_normal
        installed_something="y"
        info_progress "=> done"
    else
        info_progress "=> already installed"
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
        info_progress "=> done"
    else
        info_progress "=> already installed"
    fi

    if [ "${installed_something}" == "n" ]
    then
        info ""
        warn "Everything was already installed."
        info "> run '> overnode upgrade' to upgrade."
        info "> run '> overnode install --force' to re-install."
    fi
    
    println "[-] Installed"
}

upgrade_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="h" --longoptions="version:,help" --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    version="master"
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}upgrade [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}--version VERSION${no_c}
             Specific version to upgrade to. Default is latest available.
             See available version online:
             https://github.com/avkonst/overnode/releases
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
            --version)
                version=$2
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

    [ ! -f /tmp/install.sh ] || rm /tmp/install.sh
    cmd="wget -q --no-cache -O /tmp/install.sh https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh"
    run_cmd_wrap $cmd || {
        exit_error "failure to download file: https://raw.githubusercontent.com/avkonst/overnode/${version}/install.sh" \
            "Failed command:" "> $cmd" \
            "Is version '${version}' correct?" \
            "See available versions online: https://github.com/avkonst/overnode/releases"
    }
    chmod a+x /tmp/install.sh

    cmd="/tmp/install.sh --force"
    run_cmd_wrap $cmd || {
        exit_error "upgrade unsuccessful: /tmp/install.sh script exited abnormally" "Failed command:" "> $cmd"
    }
    
    # the install.sh will invoke new overnode install and it will print the final status
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
        hostname: overnode.weave.local
        image: ${image_proxy}
        init: true
        environment:
            WEAVE_CIDR: 10.39.240.${node_id}/12
        volumes:
            - /etc/overnode/volume:/overnode.etc
            - overnode:/overnode
            - ${weave_run}:/var/run/weave:ro
        labels:
            - works.weave.role=system
            - org.overnode.role=system
        restart: always
        network_mode: bridge
        command: TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/weave/weave.sock
volumes:
    overnode:
        driver: local
        name: overnode
        labels:
            - org.overnode.role=system
""" > /etc/overnode/system.yml
}

launch_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options="h" --longoptions=token:,id:,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    token=""
    node_id=""
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}launch --id ID [OPTION] --token TOKEN ... [HOST] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}HOST${no_c}       Peer nodes to connect to in order to form a cluster.
  ${cyan_c}--id ID${no_c}    Unique within a cluster node identifier. Number from 1 to 255.
  ${cyan_c}--token TOKEN${no_c}
             Same password shared by the nodes in a cluster.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
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

    pat="^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        exit_error "invalid argument: id, required: number [1-255], received: $node_id" "Run '> overnode ${current_command} --help' for more information"
    fi

    info_progress "Launching weave ..."
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        export CHECKPOINT_DISABLE=1
        cmd="weave launch --plugin=false --password=${token} --dns-domain=weave.local. --rewrite-inspect \
            --ipalloc-range 10.40.0.0/13 --ipalloc-default-subnet 10.32.0.0/12 --ipalloc-init seed=::1,::2,::3,::4 \
            --name=::${node_id} $@"
        debug_cmd $cmd
        output=$($cmd) && weave_running=$? || weave_running=$?
        if [[ $weave_running -ne 0 ]]
        then
            cid=$(docker ps --all | grep weave | head -n 1 | awk '{print $1}')
            exit_error "weave container terminated abnormally" "Run '> docker logs ${cid}' for more information"
        fi
        info_progress "=> done: $output"
    else
        info_progress "=> already running"
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

source_file=$1

source_dir="/tmp/overnode.etc"
[ -d ${source_dir} ] && rm -Rf ${source_dir}/*
[ -d ${source_dir} ] || mkdir ${source_dir}

if [ -f "${source_file}" ] # file may not exist when down clean up case
then
    tar x -f "${source_file}" -C "${source_dir}"
fi

target_dir=$2
[ -d "${target_dir}" ] || mkdir ${target_dir}

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
        
    cmd="docker cp /tmp/.overnode/. overnode:/overnode"
    run_cmd_wrap $cmd || {
        exit_error "failure to upload files to the overnode volume" "Failed command:" "> $cmd"
    }
    rm -Rf /tmp/.overnode

    println "[$node_id] Node launched"
}

resume_action() {
    shift
    ensure_no_args $@    
    
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        info_progress "Resuming weave ..."
        cmd="docker start weave"
        run_cmd_wrap $cmd  > /dev/null || {
            exit_error "failure to start weave" "Failed command:" "> $cmd"
        }
        info_progress "=> done"
    else
        info_progress "Resuming weave ..."
        info_progress "=> already running"
    fi
    
    info_progress "Resuming agent ..."
    if [ "$(docker ps --filter name=overnode -q)" == "" ]
    then
        cmd="docker start overnode"
        run_cmd_wrap $cmd > /dev/null || {
            exit_error "failure to start agent" "Failed command:" "> $cmd"
        }
        info_progress "=> done"
    else
        info_progress "=> already running"
    fi

    node_id=$(cat /etc/overnode/id)
    println "[$node_id] Node resumed"
}

reset_action() {
    shift
    ensure_no_args $@    
    
    tmp=$(weave status 2>&1) && weave_running=$? || weave_running=$?
    if [ $weave_running -ne 0 ]
    then
        info_progress "Destroying agent ..."
        if [ -f /etc/overnode/system.yml ]
        then
            cmd="docker run --rm \
                -v /etc/overnode/system.yml:/docker-compose.yml \
                -v /var/run/docker.sock:/var/run/docker.sock \
                ${image_compose} --compatibility down --remove-orphans --volumes"
            run_cmd_wrap $cmd || {
                exit_error "failure to reset agent" "Failed command:" "> $cmd"
            }

            rm /etc/overnode/system.yml
            info_progress "=> done"
        else
            info_progress "=> already destroyed"
        fi

        info_progress "Destroying weave ..."
        cmd="weave reset --force"
        run_cmd_wrap $cmd >/dev/null 2>&1 || {
            exit_error "failure to reset weave" "Failed command:" "> $cmd"
        }
        info_progress "=> already destroyed"
    else
        if [ $(weave ps | grep -v expose | grep -v 10.39.240 | wc -l) -ne 0 ]
        then
            exit_error "there are registered services" \
                "Run '> overnode down' to destroy the services" \
                "Run '> overnode status --endpoints' for more information."
        fi
    
        weave_socket=$(weave config)
        weave_run=${weave_socket#-H=unix://}
        weave_run=${weave_run%/weave.sock}

        info_progress "Destroying agent ..."
        if [ -f /etc/overnode/system.yml ]
        then
            cmd="docker run --rm \
                -v /etc/overnode/system.yml:/docker-compose.yml \
                -v ${weave_run}:${weave_run}:ro \
                ${image_compose} ${weave_socket} --compatibility down --remove-orphans --volumes"
            run_cmd_wrap $cmd || {
                exit_error "failure to reset agent" "Failed command:" "> $cmd"
            }
            rm /etc/overnode/system.yml || {
                warn "failure to delete file: /etc/overnode/system.yml"
            }
            info_progress "=> done"
        else
            info_progress "=> already destroyed"
        fi
        
        info_progress "Destroying weave ..."
        cmd="weave reset --force"
        run_cmd_wrap $cmd || {
            exit_error "failure to reset weave" "Failed command:" "> $cmd"
        }
        info_progress "=> done"
    fi

    if [ -f /etc/overnode/id ]
    then
        node_id=$(cat /etc/overnode/id)
        cmd="rm /etc/overnode/id"
        run_cmd_wrap $cmd || {
            exit_error "failure to delete file: /etc/overnode/id" "Run '> ${cmd}' to recover the state"
        }
    else
        node_id="-"
    fi

    println "[$node_id] Node reset"
}

prime_action() {
    shift
    ensure_no_args $@    
    
    cmd="weave prime $@"
    run_cmd_wrap $cmd || {
        exit_error "failure to prime node" "Failed command:" "> $cmd"
    }
    
    node_id=$(cat /etc/overnode/id)
    println "[$node_id] Node ready"
}

overnode_client_container_id=""
cleanup_child() {
    if [ ! -z "$overnode_client_container_id" ]
    then
        unset OVERNODE_SESSION_ID
        cmd="docker kill $overnode_client_container_id"
        run_cmd_wrap $cmd > /dev/null 2>&1 || {
           warn "failure to kill session container" "Run '> $cmd' to recover the state"
        }
    fi
}

node_peers=""
get_nodes() {
    if [ -z "${node_peers}" ]
    then
        node_peers=$(weave status peers | grep -v "-" | sed 's/^.*[:][0]\?[0]\?//' | sed 's/(.*//')
        failed_connections_count=$(weave status connections | grep -v established | grep -v "connect to ourself" | wc -l)
        if [ ${failed_connections_count} -ne 0 ] && [ -z "${1:-}" ]
        then
            return 1
        fi
    fi
    return 0
}

init_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=force,restore,project:,ignore-unreachable-nodes,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    force=""
    restore=""
    ignore_unreachable_nodes=""
    server=""
    project_id=$(pwd | sed 's#.*/##')
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} --restore PROJECT-ID [OPTION] ... [TEMPLATE] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}TEMPLATE${no_c}   Path to git repository and an optional subfolder within
             the repository, separated by '#' character.
             The remote content will be copied to the current directory.
             overnode.yml file will be extended by the remote config.
             Example: https://github.com/avkonst/overnode#examples/sleep
  ${cyan_c}--project PROJECT-ID${no_c}
             Configuration project ID to restore or initialise.
             Default is the name of the current parent directory.
  ${cyan_c}--restore${no_c}  Restore the existing configuration from other nodes.
  ${cyan_c}--force${no_c}    Force to replace the existing overnode.yml by
             the configuration for PROJECT-ID sourced from peer nodes.
             If --restore option is not defined, reset to empty configuration.
  ${cyan_c}--ignore-unreachable-nodes${no_c}
             Skip checking if all target nodes are reachable.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
            --project)
                project_id=$2
                shift 2
                ;;
            --force)
                force="y"
                shift
                ;;
            --restore)
                restore="y"
                shift
                ;;
            --ignore-unreachable-nodes)
                ignore_unreachable_nodes="y"
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
    
    if [ -z "${project_id}" ]
    then
        exit_error "invalid argument: project, non-empty value required" \
            "Run '> overnode ${current_command} --help' for more information"
    fi
    
    curdir="$(pwd -P)"
    session_id="$(date +%s%N| xargs printf "0x%x" | sed 's/0x//')"
    weave_socket=$(weave config)
    docker_path=$(which docker)
    
    trap "rm -Rf .overnode || true" EXIT
    [ -d .overnode ] || mkdir .overnode
    
    if [ ! -f overnode.yml ] || [ ! -z "$force" ]
    then
        [ ! -f .overnodeignore ] || rm .overnodeignore
        echo """.overnode
.overnodeignore
.overnodebundle
""" > .overnodeignore

        [ ! -f .env ] || rm .env
        echo """# set values for custom environment variables referenced in the compose files
""" > .env

        if [ ! -z "${restore}" ]
        then
            [ ! -f overnode.yml ] || rm overnode.yml
            echo """# Unique project id. Do not delete this field.
# It is OK to set it to some recognisable name initially.
# Once defined and set, do not edit.
id: ${project_id}

# Hint: run the following command to add sample service to the configuration
# > overnode init https://github.com/avkonst/overnode#examples/sleep

""" > overnode.yml
        else
            get_nodes ${ignore_unreachable_nodes} || {
                exit_error "some target nodes are unreachable" \
                    "Run '> overnode status --targets --peers --connections' for more information." \
                    "Run '> overnode ${current_command} --ignore-unreachable-nodes' to ignore this error."
            }
            
            this_node_id=$(cat /etc/overnode/id)
            for peer_id in $node_peers
            do
                if [ "${peer_id}" == "${this_node_id}" ] && [ $(echo $node_peers | wc -w) -gt 1 ]
                then
                    continue
                fi
                cmd="docker ${weave_socket} run --rm \
                    --label works.weave.role=system \
                    --name overnode-session-${session_id} \
                    -v $curdir:/wdir \
                    -v ${docker_path}:${docker_path} \
                    -w /wdir \
                    ${image_compose} \
                    docker -H=10.39.240.${peer_id}:2375 cp overnode:/overnode.etc ./.overnode"
                run_cmd_wrap $cmd || {
                    exit_error "failure to source configs from peer node" "Failed command:" "> $cmd" 
                }
                
                cp_cmd="cp -r ./.overnode/overnode.etc/${project_id}/* ./"
                run_cmd_wrap $cp_cmd >/dev/null 2>&1 && [ -f overnode.yml ] && {
                    rm -Rf ./.overnode/*
                    break
                } || {
                    debug "node '${peer_id}' does not store '${project_id}' project configuration"
                    rm -Rf ./.overnode/*
                    true
                }
            done
        fi
    fi
    
    for remote_repo in $@
    do
        IFS='#' read -a parts <<< ${remote_repo}
        target_dir=$(echo ${parts[0]} | sed -e 's/.*\///g')
        cmd="docker run --rm \
            --label works.weave.role=system \
            --name overnode-session-${session_id} \
            -v $curdir/.overnode:/wdir \
            -w /wdir \
            ${image_git} \
            clone ${parts[0]} ${target_dir}"
        run_cmd_wrap $cmd || {
            exit_error "failure to source configs from git repository" "Failed command:" "> $cmd" 
        }
        
        subdir="${parts[1]:-}"
        [ -d "./.overnode/${target_dir}/${subdir}" ] || {
            exit_error "invalid argument: sub-directory '${subdir}' does not exist in the remote repository" "Run '> overnode ${current_command} --help' for more information"
        }
        
        if [ -f "./.overnode/${target_dir}/${subdir}/overnode.yml" ]
        then
            config_to_merge=$(cat "./.overnode/${target_dir}/${subdir}/overnode.yml" | grep -v -e '^id: [ ]*[a-zA-Z0-9_-]*$')
            echo """
# Sourced from: ${parts[0]}/${subdir}/overnode.yml
${config_to_merge}
""" >> overnode.yml
            rm "./.overnode/${target_dir}/${subdir}/overnode.yml"
        fi

        if [ -f "./.overnode/${target_dir}/${subdir}/.overnodeignore" ]
        then
            config_to_merge=$(cat "./.overnode/${target_dir}/${subdir}/.overnodeignore")
            echo """
# Sourced from: ${parts[0]}/${subdir}/.overnodeignore
${config_to_merge}
""" >> .overnodeignore
            rm "./.overnode/${target_dir}/${subdir}/.overnodeignore"
        fi

        if [ -f "./.overnode/${target_dir}/${subdir}/.env" ]
        then
            config_to_merge=$(cat "./.overnode/${target_dir}/${subdir}/.env")
            echo """
# Sourced from: ${parts[0]}/${subdir}/.env
${config_to_merge}
""" >> .env
            rm "./.overnode/${target_dir}/${subdir}/.env"
        fi
        
        cp_cmd="cp -R ./.overnode/${target_dir}/${subdir}/* ./"
        run_cmd_wrap $cp_cmd || {
            exit_error "failure to copy configs to the current directory" "Failed command:" "> $cp_cmd" 
        }
    done
}

connect_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=replace,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    replace=""
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}connect [OPTION] ... HOST ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}HOST${no_c}       Hostnames or IP addresses of target peer nodes.
  ${cyan_c}--replace${no_c}  Forget all existing target peer nodes.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
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

    cmd="weave connect ${replace} $@"
    run_cmd_wrap $cmd || {
        exit_error "failure to connect peers" "Failed command:" "> $cmd"
    }
}

forget_action() {
    shift
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} [OPTION] ... HOST ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}HOST${no_c}       Hostnames or IP addresses of target peer nodes.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
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

    cmd="weave forget $@"
    run_cmd_wrap $cmd || {
        exit_error "failure to forget peers" "Failed command:" "> $cmd"
    }
}

declare -A settings
settings_env=""
read_settings_file()
{
    seen_sections=""
    seen_files=""
    file="$1"
    while IFS=":" read -r key value; do
        case "$key" in
        *)
            key=$(echo "$key" | sed -e 's/#.*//g') # remove comments
            value=$(echo \\"${value}" | sed -e 's/#.*//g' | xargs) # remove comments and trim spaces
            
            if [[ ! -z "${key// /}" ]] # if string includes something useful
            then
                pat="^\s*[a-zA-Z0-9_.-]+\s*$"
                if [[ $key =~ $pat ]]
                then
                    key_trimmed=$(echo "$key" | xargs) # trim spaces
                    if [ -z "${value// /}" ] && [ "$key" == "$key_trimmed" ]
                    then
                        for sn in ${seen_sections}
                        do
                            if [ "${sn}" == "${key_trimmed}" ]
                            then
                                exit_error "invalid configuration file: duplicate '$key_trimmed' section" \
                                    "Check out documentation about configuration file format"
                            fi
                        done

                        seen_sections="${seen_sections} ${key_trimmed}"
                        settings_env="${settings_env} --env OVERNODE_CONFIG_$(echo ${key_trimmed}_ID | tr a-z- A-Z_)=$(echo ${seen_sections} | wc -w)"
                        seen_files=""
                    else
                        # value within the current section
                        for sn in ${seen_files}
                        do
                            if [ "${sn}" == "${key_trimmed}" ]
                            then
                                exit_error "invalid configuration file: duplicate '$key_trimmed' key" \
                                    "Check out documentation about configuration file format"
                            fi
                        done
                        seen_files="${seen_files} ${key_trimmed}"
                        
                        if [ "${key_trimmed}" == "id" ]
                        then
                            settings[id]=${value// /}
                        else
                            set -f # in order to disable * expansion to file names
                            for nid in ${value//,/ }
                            do
                                pat="[0-9]+[-][0-9]+"
                                if [[ ${nid} =~ $pat ]]
                                then
                                    for snid in $(seq ${nid//-/ })
                                    do
                                        settings[$snid]="${settings[$snid]:-} ${key_trimmed}"
                                    done
                                else
                                    settings[$nid]="${settings[$nid]:-} ${key_trimmed}"
                                fi
                            done
                            unset -f
                        fi
                    fi
                else
                    exit_error "invalid configuration file: key '${key// /}' contains not allowed characters" \
                        "Check out documentation about configuration file format"
                fi
            fi
            ;;
        esac
    done < <(printf '%s\n' "$(cat $file)")
    
    if [ -z "${settings[id]:-}" ]
    then
        exit_error "invalid configuration file: key 'id' does not exist" \
            "Check out documentation about configuration file format"
    fi
    settings[id]=${settings[id]// /}
    pat="^[a-zA-Z0-9_-]+$"
    if ! [[ ${settings[id]} =~ $pat ]]
    then
        exit_error "invalid configuration file: value 'id' contains not allowed characters" \
            "Check out documentation about configuration file format"
    fi
}

login_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=u:,p:,h --longoptions=username:,password:,password-stdin,server:,help --name "[overnode] Error: invalid argument(s)" -- "$@")
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
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}login [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}-u|--username USERNAME${no_c}
             Account name known to a repository of container images.
  ${cyan_c}-p|--password PASSWORD${no_c}
             Associated account's password.
  ${cyan_c}--password-stdin${no_c}
             Read password from standard input.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
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

    if [ -z "$username" ]
    then
        exit_error "expected argument: username" "Run '> overnode ${current_command} --help' for more information"
    fi

    cmd="docker login ${username} ${password} ${server}"
    run_cmd_wrap $cmd || {
        exit_error "unsuccessful login" "Failed command:" "> $cmd"
    }

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
    
    cmd="cp $source_config ./docker-config.json"
    run_cmd_wrap $cmd || {
        exit_error "failure to save file: ./docker-config.json" "Failed command:" "> $cmd"
    }
    println "[*] Created ./docker-config.json"
}

logout_action() {
    shift
    ensure_no_args $@
    
    if [ -f ./docker-config.json]
    then
        cmd="rm ./docker-config.json"
        run_cmd_wrap $cmd || {
            exit_error "failure to remove file: ./docker-config.json" "Failed command:" "> $cmd"
        }
        println "[*] Removed ./docker-config.json"
    else
        println "[*] Already removed ./docker-config.json"
    fi
}

health_check() {
    srv_tmp="${2:-}"
    if [ ! -z "$srv_tmp" ]
    then
        srv_tmp="${srv_tmp} "
    fi
    info_no_prefix "[$1] Checking ${srv_tmp}..."
    cmd="$0 --no-color ps --unhealthy --nodes $1 $srv_tmp"
    while true
    do
        debug_cmd $cmd
        unhealthy_output=$($cmd 2>&1 | tail -n +3)
        [ $? -eq 0 ] || exit_error "health check command failed" "Failed command:" "> $cmd"
        pat="Up\s+[(]health[:]\s+starting[)]"
        if [[ "${unhealthy_output}" =~ $pat ]]
        then
            debug "health check: starting: '${unhealthy_output}'"
            debug_cmd sleep 10
            sleep 10
        elif [[ -z "${unhealthy_output}" ]]
        then
            return 0
        else
            debug "health check: unhealthy: '${unhealthy_output}'"
            return 1
        fi
    done
}

compose_action() {
    command=$1
    shift
    
    getopt_allow_tailargs="n"
    getopt_args="nodes:,serial,ignore-unreachable-nodes,help"
    help_text="""
"""
    help_tailargs=""
    
    opt_detach=""
    opt_collected=""
    case "$command" in
        config)
            getopt_args="${getopt_args},resolve-image-digests,no-interpolate,quiet,services,volumes,hash"
            help_text="""
  ${cyan_c}--resolve-image-digests${no_c}
             Pin image tags to digests.
  ${cyan_c}--no-interpolate${no_c}
             Don't interpolate environment variables.
  ${cyan_c}--quiet${no_c}    Only validate the configuration, don't print anything.
  ${cyan_c}--services${no_c} Print the service names, one per line.
  ${cyan_c}--volumes${no_c}  Print the volume names, one per line.
  ${cyan_c}--hash${no_c}     Print the hashes of the configured services, one per line.
"""
            ;;
        up)
            getopt_args="${getopt_args},remove-orphans,attach,quiet-pull,force-recreate,no-recreate,no-start,timeout:,rollover"
            opt_detach="-d"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--attach${no_c}   Once up and running attach to the logging output from containers.
  ${cyan_c}--remove-orphans${no_c}
             Remove containers for services not defined in
             the configuration files.
  ${cyan_c}--quiet-pull${no_c}
             Pull without printing progress information.
  ${cyan_c}--force-recreate${no_c}
             Recreate containers even if their configuration
             and image haven't changed.
  ${cyan_c}--no-recreate${no_c}
             If containers already exist, don't recreate
             them. Incompatible with --force-recreate.
  ${cyan_c}--no-start${no_c} Don't start the services after creating them.
  ${cyan_c}--timeout TIMEOUT${no_c}
             Use this timeout in seconds for container
             shutdown when attached or when containers are
             already running. (default: 10)
  ${cyan_c}--rollover${no_c} Execute controlled serial launch of services.
             If at least one SERVICE argument is specified,
             brinds each SERVICE up, one by one on each required node.
             If SERVICE argument is not specified,
             brinds each node up, one by one.
             Continues iterations only if the launched services / nodes
             are in healthy state.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        down)
            getopt_args="${getopt_args},remove-orphans,remove-images,remove-volumes,timeout:"
            help_text="""
  ${cyan_c}--remove-orphans${no_c}
             Remove containers for services not defined in
             the configuration files.
  ${cyan_c}--remove-images${no_c}
             Remove images used by the services.
  ${cyan_c}--remove-volumes${no_c}
             Remove named volumes declared in the 'volumes'
             section of the Compose file and anonymous volumes
             attached to containers.
  ${cyan_c}--timeout TIMEOUT${no_c}
             Specify a shutdown timeout in seconds. (default: 10)
"""
            ;;
        logs)
            getopt_allow_tailargs="y"
            getopt_args="${getopt_args},follow,timestamps,tail:"
            if [ ! -z "$no_color_mode" ]
            then
                opt_collected="${opt_collected} --no-color"
            fi
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--follow${no_c}   Follow log output.
  ${cyan_c}--timestamps${no_c}
             Show timestamps.
  ${cyan_c}--tail LINES${no_c}
             Number of lines to show from the end of the logs
             for each container.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        events)
            getopt_args="${getopt_args},json"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--json${no_c}     Output events as a stream of json objects.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        kill)
            getopt_args="${getopt_args},signal:"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--signal SIGNAL${no_c}
             SIGNAL to send to the container. Default signal is SIGKILL.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        ps)
            getopt_args="${getopt_args},quiet,services,filter:,all,unhealthy"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--quiet${no_c}    Only display IDs.
  ${cyan_c}--services${no_c} Display services.
  ${cyan_c}--filter KEY=VAL${no_c}
             Filter services by a property.
  ${cyan_c}--all${no_c}      Show all stopped containers,
             including those created by the run command.
  ${cyan_c}--unhealthy${no_c}
             Show only those exited abnormally or in unhealthy state.
             '--quiet' option is ignored.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        pull)
            getopt_args="${getopt_args},quiet,include-deps,no-parallel,ignore-pull-failures"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--quiet${no_c}    Pull without printing progress information.
  ${cyan_c}--include-deps${no_c}
             Also pull services declared as dependencies.
  ${cyan_c}--no-parallel${no_c}
             Disable parallel pulling.
  ${cyan_c}--ignore-pull-failures${no_c}
             Pull what it can and ignore images with pull failures.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        push)
            getopt_args="${getopt_args},ignore-push-failures"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--ignore-push-failures${no_c}
             Push what it can and ignore images with push failures.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        restart)
            getopt_args="${getopt_args},timeout:"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--timeout TIMEOUT${no_c}
             Specify a shutdown timeout in seconds. (default: 10).
"""
            help_tailargs="[SERVICE] ..."
            ;;
        rm)
            getopt_args="${getopt_args},stop,remove-volumes"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--stop${no_c}     Stop the containers, if required, before removing.
  ${cyan_c}--remove-volumes${no_c}
             Remove any anonymous volumes attached to containers.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        stop)
            getopt_args="${getopt_args},timeout:"
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
  ${cyan_c}--timeout TIMEOUT${no_c}
             Specify a shutdown timeout in seconds. (default: 10)
"""
            help_tailargs="[SERVICE] ..."
            ;;
        top|pause|unpause|start)
            getopt_allow_tailargs="y"
            help_text="""
  ${cyan_c}SERVICE${no_c}    List of services to target for the action.
"""
            help_tailargs="[SERVICE] ..."
            ;;
        *)
            exit_error "internal: $command" "Please report this bug to https://github.com/avkonst/overnode/issues"
            ;;
    esac
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=${getopt_args} --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    node_ids=""
    serial=""
    ignore_unreachable_nodes=""
    ps_unhealthy=""
    up_rollover=""
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} [OPTION] ... ${help_tailargs}${no_c}

  Options:   Description:
  ${line}${help_text}  ${cyan_c}--nodes NODE,...${no_c}
             Comma separated list of nodes to target for the action.
             By default, all known nodes are targeted.
  ${cyan_c}--ignore-unreachable-nodes${no_c}
             Skip checking if all target nodes are reachable.
  ${cyan_c}--serial${no_c}   Execute the command node by node, not in parallel.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
            --nodes)
                node_ids=$2
                shift 2
                ;;
            --serial)
                serial="y"
                shift
                ;;
            --ignore-unreachable-nodes)
                ignore_unreachable_nodes="y"
                shift
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
                if [ ! -z "$up_rollover" ]
                then
                    exit_error "invalid argument: attach, not compatible with rollover" "Run '> overnode ${current_command} --help' for more information"
                fi
                opt_detach=""
                shift
                ;;
            --timeout)
                pat="^[0-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    exit_error "invalid argument: timeout, required: number, received: $2" "Run '> overnode ${current_command} --help' for more information"
                fi
                opt_collected="${opt_collected} --timeout $2"
                shift 2
                ;;
            --tail)
                pat="^[0-9]+$"
                if ! [[ $2 =~ $pat ]]
                then
                    exit_error "invalid argument: tail, required: number, received: $2" "Run '> overnode ${current_command} --help' for more information"
                fi
                opt_collected="${opt_collected} --tail $2"
                shift 2
                ;;
            --hash)
                opt_collected="--hash=*" # keep it simple with predefined wildcard, because it is hard to validate the option
                shift
                ;;
            --signal)
                opt_collected="-s $2"
                shift 2
                ;;
            --filter)
                opt_collected="--filter $2"
                shift 2
                ;;
            --unhealthy)
                ps_unhealthy="y"
                shift
                ;;
            --rollover)
                if [ -z "$opt_detach" ]
                then
                    exit_error "invalid argument: attach, not compatible with rollover" "Run '> overnode ${current_command} --help' for more information"
                fi
                up_rollover="y"
                shift
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

    if [ ! -z "${ps_unhealthy}" ]
    then
        if [ ! -z "${node_ids}" ]
        then
            nodes_arg="--nodes ${node_ids}"
        fi
        $0 --no-color ps ${opt_collected//--quiet/} ${nodes_arg:-} ${required_services} 2>&1 | grep -v -E '\s+Up\s+[(]healthy[)]|\s+Up\s*$|\s+Up\s+[^(]|\s+Exit\s+0' 1>&2
        return $?
    fi

    get_nodes ${ignore_unreachable_nodes} || {
        exit_error "some target nodes are unreachable" \
            "Run '> overnode status --targets --peers --connections' for more information." \
            "Run '> overnode ${current_command} --ignore-unreachable-nodes' to ignore this error." \
            "Run '> overnode ${current_command} --nodes ${node_peers// /,}' to target only reachable nodes."
    }

    node_ids=${node_ids//[,]/ }
    node_ids=${node_ids:-$node_peers}
    node_ids=$(echo "${node_ids}" | tr ' ' '\n' | sort | uniq | xargs) # remove duplicates

    for node_id in $node_ids
    do
        pat="^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$"
        if [[ $node_id =~ $pat ]]
        then
            true
        else
            exit_error "invalid argument: nodes, required: comma separated numbers [1-255], received: ${node_id}" "Run '> overnode ${current_command} --help' for more information"
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
            exit_error "invalid argument: nodes, node is unknown or unreachable: ${node_id}" \
                "Run '> overnode status --targets --peers --connections' for more information."
        fi
    done
    
    if [ ! -f ./overnode.yml ]
    then
        exit_error "configuration file does not exist: ./overnode.yml" \
            "Run '> touch ./overnode.yml' to create empty configuration"
    fi

    read_settings_file ./overnode.yml
    
    project_id=${settings[id]}
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

    if [ -z "${OVERNODE_SESSION_ID:-}" ]
    then
        session_id="$(date +%s%N| xargs printf "0x%x" | sed 's/0x//')"
        trap "cleanup_child" EXIT
        cmd="docker ${weave_socket} run --rm \
            -d \
            --label works.weave.role=system \
            --name overnode-session-${session_id} \
            -v $curdir:/wdir-${project_id} \
            -v overnode:/overnode \
            -v ${docker_path}:${docker_path} \
            ${docker_config_volume_arg} \
            -w /wdir-${project_id} \
            ${image_compose} sh -e /overnode/sleep-infinity.sh"
        debug_cmd $cmd
        overnode_client_container_id=$($cmd)
        export OVERNODE_SESSION_ID=${overnode_client_container_id}
    else
        overnode_client_container_id=${OVERNODE_SESSION_ID}
    fi
    
    # We lookup bridge IP only for the current host,
    # and assume all other hosts have got the same setup.
    # It allows to avoid calling remote nodes to inspect.
    # When smebody hits this limitation,
    # this can be improved in the future.
    docker_gateway=$(docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}')
    
    running_jobs=""
    all_configured_services=""
    declare -A matched_required_services_by_node
    declare -A node_configs_by_node
    for node_id in $node_ids
    do
        node_configs=""
        if exists "*" in settings
        then
            for srv in ${settings[\*]}
            do
                node_configs="${node_configs} -f ${srv}"
            done
        fi
        if exists $node_id in settings
        then
            for srv in ${settings[$node_id]}
            do
                node_configs="${node_configs} -f ${srv}"
            done
        fi
        if [ -z "${node_configs}" ]
        then
            # inject empty config only if there are no other defined by user
            # to avoid enforcing compose-file version
            node_configs="-f /overnode/system.yml"
        fi
        node_configs_by_node[$node_id]="$node_configs"
        
        matched_required_services=""
        if [ ! -z "$required_services" ]
        then
            cmd="docker exec \
                -w /wdir-${project_id} \
                --env OVERNODE_ID=${node_id} \
                --env OVERNODE_PROJECT_ID=${project_id} \
                --env OVERNODE_SESSION_ID=${OVERNODE_SESSION_ID} \
                --env OVERNODE_ETC=/etc/overnode/volume/${project_id} \
                --env OVERNODE_BRIDGE_IP=${docker_gateway} \
                ${settings_env} \
                ${overnode_client_container_id} docker-compose -H=10.39.240.${node_id}:2375 --compatibility ${node_configs_by_node[$node_id]} \
                config --services"
            debug_cmd $cmd
            configured_services=$($cmd 2> /dev/null)
            if [ $? -ne 0 ]
            then
                exit_error "failure to verify configuration" \
                    "Run '> overnode config --nodes ${node_id} --services' for more information"
            fi
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

    if [ ! -z "${up_rollover}" ]
    then
        if [ -z "${required_services}" ]
        then
            # execute node by node
            for node_id in $node_ids
            do
                cmd="$0 up ${opt_collected} --nodes ${node_id}"
                run_cmd_wrap $cmd || exit_error "overnode up command failed" "Failed command:" "> $cmd"
                health_check $node_id || exit_error "health check failed" \
                    "Run '> overnode ps --unhealthy --nodes $node_id' for more information"
            done
        else
            # execute service by service on each node
            for srv in $required_services
            do
                for node_id in $node_ids
                do
                    for msrv in ${matched_required_services_by_node[$node_id]}
                    do
                        if [ "${msrv}" == "${srv}" ]
                        then
                            cmd="$0 up ${opt_collected} --nodes ${node_id} $srv"
                            run_cmd_wrap $cmd || exit_error "overnode up command failed" "Failed command:" "> $cmd"
                            health_check $node_id $srv || exit_error "health check failed" \
                                "Run '> overnode ps --unhealthy --nodes $node_id $srv' for more information"
                            break
                        fi
                    done
                done
            done
        fi
        exit_success
    fi

    for node_id in $node_ids
    do
        if [ -z "$required_services" ] || [ ! -z "${matched_required_services_by_node[$node_id]}" ]
        then
            if [ ${command} == "up" ]
            then
                if [ -z ${tar_done:-} ]
                then
                    if [ -f .overnodeignore ]
                    then
                        tar_exclude_patterns="-X .overnodeignore"
                    fi
                    
                    [ ! -f .overnodebundle ] || rm .overnodebundle
                    tar_cmd="tar c -h -f .overnodebundle --exclude .overnodebundle ${tar_exclude_patterns:-} ./"
                    run_cmd_wrap $tar_cmd || {
                        exit_error "failure to archive the current directory" "Failed command:" "> $tar_cmd"
                    }
                    tar_done="y"
                fi
            
                cp_cmd="docker exec \
                    ${overnode_client_container_id} docker -H=10.39.240.${node_id}:2375 \
                    cp .overnodebundle overnode:/tmp \
                "
                debug_cmd $cp_cmd

                rm_cmd="docker exec \
                    ${overnode_client_container_id} docker -H=10.39.240.${node_id}:2375 \
                    exec -w /overnode.etc overnode sh /overnode/sync-etc.sh /tmp/.overnodebundle /overnode.etc/${project_id} /etc/overnode/volume/${project_id} \
                "
                debug_cmd $rm_cmd
            fi
            
            if [ ${command} == "down" ]
            then
                rm_cmd_down="docker exec \
                    ${overnode_client_container_id} docker -H=10.39.240.${node_id}:2375 \
                    exec -w /overnode.etc overnode sh /overnode/sync-etc.sh /tmp/.doesnotexist /overnode.etc/${project_id} /etc/overnode/volume/${project_id} \
                "
                debug_cmd $rm_cmd_down
            fi
            
            # each client in the same container
            cmd="docker exec \
                -w /wdir-${project_id} \
                --env OVERNODE_ID=${node_id} \
                --env OVERNODE_PROJECT_ID=${project_id} \
                --env OVERNODE_SESSION_ID=${OVERNODE_SESSION_ID} \
                --env OVERNODE_ETC=/etc/overnode/volume/${project_id} \
                --env OVERNODE_BRIDGE_IP=${docker_gateway} \
                ${settings_env} \
                ${overnode_client_container_id} docker-compose -H=10.39.240.${node_id}:2375 \
                --compatibility \
                ${node_configs_by_node[$node_id]} \
                ${command} \
                ${opt_collected} \
                ${opt_detach}\
                ${matched_required_services_by_node[$node_id]} \
            "
            if [ -z "$serial" ]
            then
                # in background
                debug_cmd $cmd
                { { { ${cp_cmd:-true} && ${rm_cmd:-true}; } && $cmd && ${rm_cmd_down:-true}; } 2>&3 | prepend_stdout "[$node_id]"; } 3>&1 1>&2 | prepend_stderr "[$node_id]" &
                running_jobs="${running_jobs} $!"
            else
                # in foreground
                debug_cmd $cmd
                { { { ${cp_cmd:-true} && ${rm_cmd:-true}; } && $cmd && ${rm_cmd_down:-true}; } 2>&3 | prepend_stdout "[$node_id]"; } 3>&1 1>&2 | prepend_stderr "[$node_id]"
                if [ $? -ne 0 ]
                then
                    exit 1
                fi
            fi
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
    ! PARSED=$(getopt --options=h --longoptions=inline,ignore-unreachable-nodes,id:,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    node_id=""
    inline=""
    ignore_unreachable_nodes=""
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}env --id ID [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}--id ID${no_c}    Target peer node identifier.
  ${cyan_c}-inline${no_c}    If specified, prints -H option for docker command line.
             Otherwise, prints the spec for DOCKER_HOST environment variable.
  ${cyan_c}--ignore-unreachable-nodes${no_c}
             Skip checking if all target nodes are reachable.
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
            --inline)
                inline="y"
                shift
                ;;
            --ignore-unreachable-nodes)
                ignore_unreachable_nodes="y"
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
    
    pat="^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$"
    if [[ $node_id =~ $pat ]]
    then
        true
    else
        exit_error "invalid argument: id, required number [1-255], received: $node_id" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    # print to stdout in any case
    if [ -z "${inline}" ]
    then
        println "export DOCKER_HOST=10.39.240.${node_id}:2375 ORIG_DOCKER_HOST=${DOCKER_HOST:-}"
    else
        println "-H=10.39.240.${node_id}:2375"
    fi

    if [ ! -z "${quiet}" ]
    then
        return 0
        exit_success
    fi

    get_nodes ${ignore_unreachable_nodes} || {
        exit_error "some target nodes are unreachable" \
            "Run '> overnode status --targets --peers --connections' for more information." \
            "Run '> overnode ${current_command} --ignore-unreachable-nodes' to ignore this error."
    }

    for peer_id in $node_peers
    do
        if [[ "${node_id}" == "${peer_id}" ]]
        then
            ip_addrs=$(weave dns-lookup overnode)
            for addr in $ip_addrs
            do
                if [[ "10.39.240.${node_id}" == $addr ]]
                then
                    exit_success
                fi
            done
            
            exit_error "node is unreachable: ${node_id}" \
                "Run '> overnode dns-lookup overnode' to inspect agent's dns records" \
                "Run '> overnode status --targets --peers --connections' to list available nodes and connections"
        fi
    done
    
    exit_error "node is unknown or unreachable: ${node_id}" \
        "Run '> overnode status --targets --peers --connections' for more information."
}

status_action() {
    shift
    
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=targets,peers,connections,dns,ipam,endpoints,help --name "[overnode] Error: invalid argument(s)" -- "$@")
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
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}status [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}--targets|--peers|--connections|--dns|--ipam|--endpoints${no_c}
             Various toogle flags allowing to pick specific components status.
             By default, prints the status for all components.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
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
        info_progress "Targets status:"
        cmd="weave status targets"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }

        info_progress "Peers status:"
        cmd="weave status peers"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }

        info_progress "Connections status:"
        cmd="weave status connections"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }

        info_progress "DNS status:"
        cmd="weave status dns"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }

        info_progress "IPAM status:"
        cmd="weave status ipam"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }

        info_progress "Endpoints status:"
        cmd="weave ps"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi
    
    if [[ $targets == "y" ]]
    then
        info_progress "Targets status:"
        cmd="weave status targets"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi

    if [[ $peers == "y" ]]
    then
        info_progress "Peers status:"
        cmd="weave status peers"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi

    if [[ $connections == "y" ]]
    then
        info_progress "Connections status:"
        cmd="weave status connections"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi

    if [[ $dns == "y" ]]
    then
        info_progress "DNS status:"
        cmd="weave status dns"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi
    
    if [[ $ipam == "y" ]]
    then
        info_progress "IPAM status:"
        cmd="weave status ipam"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi

    if [[ $endpoints == "y" ]]
    then
        info_progress "Endpoints status:"
        cmd="weave ps"
        run_cmd_wrap $cmd || {
            exit_error "failure to read weave status" "Failed command:" "> $cmd"
        }
    fi
}

inspect_action() {
    shift
    ensure_no_args $@
    
    cmd="weave report"
    run_cmd_wrap $cmd || {
        exit_error "failure to read weave status" "Failed command:" "> $cmd"
    }
}

expose_weave() {
    cmd="weave expose"
    run_cmd_wrap $cmd || {
        exit_error "failure to expose weave" "Failed command:" "> $cmd"
    }
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
    cmd="weave hide"
    run_cmd_wrap $cmd || {
        exit_error "failure to hide weave" "Failed command:" "> $cmd"
    }
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
    ! PARSED=$(getopt --options=h --longoptions=ips:,name:,help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    ips=""
    name=""
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} --ips IP,... --name FQDN [OPTION] ...${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}--name FQDN${no_c}
             Fully qualified domain name of the DNS entry.
  ${cyan_c}--ips IP,...${no_c}
             Comma separated list of IP address to update.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
                ;;
            --ips)
                ips="${2//[,]/ }"
                shift 2
                ;;
            --name)
                if [ "$2" == *.weave.local ]
                then
                    name=$2
                else
                    name="$2.weave.local"
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
    
    if [ -z "$name" ]
    then
        exit_error "expected argument: name" "Run '> overnode ${current_command} --help' for more information"
    fi

    if [ -z "$ips" ]
    then
        exit_error "expected argument: ips" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    cmd="weave ${command} ${ips} -h ${name}"
    run_cmd_wrap $cmd || {
        exit_error "failure to alter dns record" "Failed command:" "> $cmd"
    }
}

dns_lookup_action() {
    shift
    set_console_color $red_c
    ! PARSED=$(getopt --options=h --longoptions=help --name "[overnode] Error: invalid argument(s)" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit_error "" "Run '> overnode ${current_command} --help' for more information"
    fi
    set_console_normal
    eval set -- "$PARSED"
    
    while true; do
        case "$1" in
            --help|-h)
printf """> ${cyan_c}overnode${no_c} ${gray_c}[--debug] [--no-color]${no_c} ${cyan_c}${current_command} [OPTION] ... HOSTNAME${no_c}

  Options:   Description:
  ${line}
  ${cyan_c}HOSTNAME${no_c}   Name to look up in the DNS register.
  ${line}
  ${cyan_c}-h|--help${no_c}  Print this help.
  ${line}
""";
                exit_success
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
    
    if [ $# -ne 1 ]
    then
        exit_error "expected one argument" "Run '> overnode ${current_command} --help' for more information"
    fi
    
    cmd="weave dns-lookup $@"
    run_cmd_wrap $cmd || {
        exit_error "failure to lookup dns record" "Failed command:" "> $cmd"
    }
}

run() {
    if [[ -z "$@" ]]; then
        exit_error "expected argument(s)" "Run '> overnode --help' for more information"
    fi

    # handle debug argument
    if [ $1 == "--debug" ]; then
        debug_on="true"
        shift
        if [ $1 == "--no-color" ]; then
            set_console_nocolor
            shift
        fi
    fi
    if [ $1 == "--no-color" ]; then
        set_console_nocolor
        shift
        if [ $1 == "--debug" ]; then
            debug_on="true"
            shift
        fi
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
        prime)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_overnode_running
            prime_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
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
        init)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_overnode_running
            init_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
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
        logout)
            ensure_root
            logout_action $@ || exit_error "internal unhandled" "Please report this bug to https://github.com/avkonst/overnode/issues"
            exit_success
        ;;
        config|up|down|logs|top|events|kill|pause|unpause|ps|pull|push|restart|rm|start|stop)
            ensure_root
            ensure_docker
            ensure_weave
            ensure_weave_running
            ensure_overnode_running
            compose_action $@ || exit_error
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
