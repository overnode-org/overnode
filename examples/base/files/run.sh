#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

log="Cluster Node Discovery:"

if [ "$DEVELOPMENT_MODE" == "true" ]
then
    echo "$log DEVELOPMENT mode"
else
    echo "$log PRODUCTION mode"
fi

if [ -z "$SERVICE_NAME" ]; then
    echo "SERVICE_NAME environment variable is required"
    exit 1
fi
echo "$log SERVICE_NAME $SERVICE_NAME"

#
# discover container IP address
#
container_ip=`hostname -i`
if [[ "$container_ip" != "${container_ip/ /}" ]]
then
    # it seems hostname -i returns multiple addresses (docker swarm scenario)
    # use alternative way preferable for docker swarm
    hostname=`hostname -f`
    echo "$log hostname $hostname"
    container_ip=`dig ${hostname} | grep -A 1 "ANSWER SECTION" | grep -v ";" | awk '{print $5}'`
    if [[ -z  ${container_ip}  ]]
    then
        # again a workaround for a bug in docker swarm dns
        echo "$log Container has not been registered in DNS, waiting for this 10 seconds"
        sleep 10
        container_ip=`dig ${hostname} | grep -A 1 "ANSWER SECTION" | grep -v ";" | awk '{print $5}'`
    fi
fi
echo "$log container_ip $container_ip"

#
# discover machine IP address
#
# TODO think about the alternative way
machine_ip=`cat /data/external-ip.txt`
echo "$log public_ip $machine_ip"
private_ip=`cat /data/internal-ip.txt`
echo "$log private_ip $private_ip"

#
# discover peers IP addresses
#
# SERVICE_NAME is populated with DNS name,
# which is resolved to IPs of all peer containers within a cluster
peer_ips=`dig ${SERVICE_NAME} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
echo "$log peer_ips $peer_ips"
peer_ips_by_comma=`echo ${peer_ips} | tr " " ","`
echo "$log peer_ips_by_comma $peer_ips_by_comma"

#
# setup the guard variable
#
export CLUSTER_DISCOVERY_DONE=true

#
# locate the script to execute
#
service_name_lower_case=${SERVICE_NAME/tasks./}
service_name_lower_case=${service_name_lower_case/.*/}
script_name="/run-$service_name_lower_case.sh"
if [ -f ${script_name} ];
then
    export MACHINE_IP=${machine_ip}
    export PRIVATE_IP=${private_ip}
    export CONTAINER_IP=${container_ip}
    export PEER_IPS=${peer_ips}
    export PEER_IPS_BY_COMMA=${peer_ips_by_comma}
    cmd="${script_name}"
    echo "$log Running: $cmd"
    ${cmd}
    exit_code=$?
    echo "$log Finished. Exiting the container task with code ${exit_code}"
    exit ${exit_code};
else
    echo "$log Unknown service $SERVICE_NAME, because script $script_name does not exist."
    exit 1;
fi
