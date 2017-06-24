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

version_system=0.3.4
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

debug() {
    if [[ ${debug_on} == "true" ]]; then
        (>&2 echo "$log $1")
    fi
}

usage_no_exit() {
    cat >&2 <<EOF
> clusterlite [--debug] <action> [OPTIONS]

    Actions / Options:                      | Description:
    -------------------------------------------------------------------------------------------------------------
    help                                   => Print this help information.
    version                                => Print version information.
    -------------------------------------------------------------------------------------------------------------
    install                                => Install clusterlite node on the current host and join the cluster.
      --token <cluster-wide-token>          | Token should be the same for all nodes joining the cluster.
      --seeds <host1,host2,...>             | 3-5 seeds are recommended for high-availability and reliability.
                                            | Hosts should be private IP addresses or valid DNS host names.
                                            | If 1 host is planned initially, initialize as the following:
                                            |   host1$ clusterlite install --seeds host1
                                            | When 2 more hosts are added later, initialize as the following:
                                            |   host2$ clusterlite install --seeds host1,host2,host3
                                            |   host3$ clusterlite install --seeds host1,host2,host3
                                            | If all 3 hosts are planned initially, initialize as the following:
                                            |   host1$ clusterlite install --seeds host1,host2,host3
                                            |   host2$ clusterlite install --seeds host1,host2,host3
                                            |   host3$ clusterlite install --seeds host1,host2,host3
                                            | If a host is joining as non seed host, initialize as the following:
                                            |   host4$ clusterlite install --seeds host1,host2,host3
                                            | WARNING: seeds order should be the same on all joining hosts!
      [--volume /var/lib/clusterlite]       | Directory where stateful services will persist data.
      [--public-address]                    | Public IP address of the host, if exists and requires exposure.
      [--placement default]                 | Role allocation for a node. A node schedules services
                                            | according to the matching placement
                                            | defined in the configuration file set via 'apply' action.
    uninstall                              => Destroy processes/containers, leave the cluster and remove data.
    -------------------------------------------------------------------------------------------------------------
    info                                   => Show cluster-wide information, like IDs of nodes.
    -------------------------------------------------------------------------------------------------------------
    login                                  => Provide credentials to download images from private repositories.
      --username <username>                 | Docker registry username.
      --password <password>                 | Docker registry password.
      [--registry registry.hub.docker.com]  | Address of docker registry to login to.
                                            | If you have got multiple different registries,
                                            | execute 'login' action multiple times.
                                            | Credentials can be also different for different registries.
    logout                                 => Removes credentials for a registry
      [--registry registry.hub.docker.com]  | Address of docker registry to logout from.
    -------------------------------------------------------------------------------------------------------------
    plan                                   => Review what current or new configuration requires to apply.
      [--config /path/to/yaml/file]         | The same as for 'apply' action.
    apply                                  => Apply current or new configuration and provision services.
      [--config /path/to/yaml/file]         | Configuration file for the cluster, which defines
                                            | what containers to create and where to launch them.
                                            | If it is not defined, the latest applied is used.
    show                                   => Show current status of created containers / services.
    destroy                                => Terminate and destroy all containers / services in the cluster.
    -------------------------------------------------------------------------------------------------------------
    docker                                 => Run docker command against one or multiple nodes of the cluster.
      [--nodes 1,2,..]                      | Comma separated list of IDs of nodes. If absent, applies to all.
      <docker-command> [docker-options]     | Valid docker command and options. For example:
                                            | - List running containers on node 1:
                                            |   host1$ clusterlite docker --nodes 1 ps
                                            | - Print logs for my-service container running on nodes 1 and 2:
                                            |   host1$ clusterlite docker --nodes 1,2 logs my-service
                                            | - Print running processes in my-service container across all nodes:
                                            |   host1$ clusterlite docker exec -it --rm my-service ps -ef
    -------------------------------------------------------------------------------------------------------------
    expose                                 => Allow the current host to access to the network of the cluster.
    hide                                   => Disallow the current host to access to the network of the cluster.
    lookup                                 => Execute DNS lookup against the internal DNS service of the cluster.
      <name-to-lookup>                      | Service name or container name to lookup.
    -------------------------------------------------------------------------------------------------------------
EOF
}

version_action() {
    echo "Webintrinsics Clusterlite, version $version_system"
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
        echo "$log Error: requires: docker, found: none" >&2
        debug "failure: prerequisites not satisfied" && exit 1
    fi

    if ! docker_version=$(docker -v | sed -n -e 's|^Docker version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*|\1|p') || [ -z "$docker_version" ] ; then
        echo "$log Error: unable to parse docker version" >&2
        debug "failure: prerequisites not satisfied"  && exit 1
    fi

    if version_lt ${docker_version} ${version_docker_min} ; then
        echo "${log} Error: clusterlite requires Docker version $version_docker_min or later; you are running $docker_version" >&2
        debug "failure: prerequisites not satisfied" && exit 1
    fi

    # should pass the following if the previous is passed
    if [[ $(which docker-init | wc -l) == "0" ]]
    then
        echo "$log Error: requires: docker-init binary, found: none" >&2
        debug "failure: prerequisites not satisfied" && exit 1
    fi

    docker_location="$(which docker)"
    docker_init_location="$(which docker-init)"
    weave_location="${docker_location/docker/weave}"
}

ensure_installed() {
    if [[ $1 == "" ]]; then
        echo "[clusterlite] Error: clusterlite is not installed" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: prerequisites not satisfied" && exit 1
    fi
}

ensure_not_installed() {
    if [[ $1 != "" ]]; then
        echo "[clusterlite] Error: clusterlite is already installed" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: prerequisites not satisfied" && exit 1
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
}

uninstall_action() {
    node_id=$1
    seed_id=$2
    volume=$3

    echo "${log} stopping proxy server"
    docker exec -i clusterlite-proxy /run-proxy-remove.sh ${node_id} || \
        echo "${log} warning: failure to detach the node"
    docker stop clusterlite-proxy || \
        echo "${log} warning: failure to stop clusterlite-proxy container"
    docker rm clusterlite-proxy || \
        echo "${log} warning: failure to remove clusterlite-proxy container"

    if [[ ${seed_id} != "" ]]; then
        echo "${log} stopping etcd server"
        docker exec -i clusterlite-etcd /run-etcd-remove.sh || \
            echo "${log} warning: failure to detach clusterlite-etcd server"
        docker stop clusterlite-etcd || \
            echo "${log} warning: failure to stop clusterlite-etcd container"
        docker rm clusterlite-etcd || \
            echo "${log} warning: failure to remove clusterlite-etcd container"
        rm -Rf ${volume}/clusterlite-etcd || \
            echo "${log} warning: failure to remove ${volume}/clusterlite-etcd data"
    fi

    echo "${log} uninstalling weave network"
    # see https://www.weave.works/docs/net/latest/ipam/stop-remove-peers-ipam/
    ${weave_location} reset || echo "${log} warning: failure to reset weave network"

    echo "${log} uninstalling data directory"
    rm -Rf ${volume} || echo "${log} warning: ${volume} has not been removed"
    rm -Rf /var/lib/clusterlite || echo "${log} warning: /var/lib/clusterlite has not been removed"
}

expose_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        echo "[clusterlite] Error: unknown argument $2" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: invalid argument(s)" && exit 1
    fi
    ${weave_location} expose
}

hide_action() {
    used=$1
    if [[ ! -z $2 ]]; then
        echo "[clusterlite] Error: unknown argument $2" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: invalid argument(s)" && exit 1
    fi
    ${weave_location} hide
}

lookup_action() {
    used=$1
    if [[ ! -z $3 ]]; then
        echo "[clusterlite] Error: unknown argument $3" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: invalid argument(s)" && exit 1
    fi
    if [[ -z $2 ]]; then
        echo "[clusterlite] Error: name to lookup argument is required" >&2
        echo "[clusterlite] Try 'clusterlite help' for more information." >&2
        debug "failure: invalid argument(s)" && exit 1
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
            if [[ $(which unzip || echo) == "" ]];
            then
                if [ $(uname -a | grep Ubuntu | wc -l) == 1 ]
                then
                    # ubuntu supports automated installation
                    apt-get -y update || (echo "apt-get update failed, are proxy settings correct?" && exit 1)
                    apt-get -qq -y install --no-install-recommends unzip jq
                else
                    echo "$log Error: unzip has not been found, please install unzip utility" >&2
                    exit 1
                fi
            fi
            rm -Rf ${package_dir}/clusterlite
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
        login|logout|plan|apply|destroy|show|info)
            docker_command="${docker_command} $@"
            debug "executing ${docker_command}"
            ${docker_command} | tee ${log_out}
            [[ ${PIPESTATUS[0]} == "0" ]] || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        expose)
            expose_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        hide)
            hide_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        lookup)
            lookup_action $@ || (debug "failure: action aborted" && exit 1)
            debug "success: action completed" && exit 0
        ;;
        "")
            echo "[clusterlite] Error: action argument is required" >&2
            echo "[clusterlite] Try 'clusterlite help' for more information." >&2
            echo "[clusterlite] failure: invalid argument(s)" >&2
            debug "failure: action aborted" && exit 1
        ;;
        *)
            echo "[clusterlite] Error: unknown action '$1'" >&2
            echo "[clusterlite] Try 'clusterlite help' for more information." >&2
            echo "[clusterlite] failure: invalid argument(s)" >&2
            debug "failure: action aborted" && exit 1
        ;;
    esac
}

run $@ # wrap in a function to prevent partial download