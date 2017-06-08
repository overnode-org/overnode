#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

function discover_service()
{
    service_name=$1
    local addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    local addresses_by_comma=`echo ${addresses} | tr " " ","`
    echo "$addresses"
}

if [[ ( -z  ${SERVICE_NAME} ) || ( -z  ${MACHINE_IP} ) || ( -z  ${PRIVATE_IP} ) || ( -z  ${CONTAINER_IP} ) || ( -z  ${PEER_IPS_BY_COMMA} ) || ( -z  ${PEER_IPS} ) ]]
then
    echo "Environment variable is missing. Make sure it is executed via run.sh cluster discovery service."
    exit 1
fi
