#!/bin/bash

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade zeppelin] starting..."

function discover_service()
{
    service_name=$1
    local addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    local addresses_by_comma=`echo ${addresses} | tr " " ","`
    echo "$addresses"
}

if [ -z "$SPARK_SERVICE_NAME" ]; then
    echo "[cade zeppelin] SPARK_SERVICE_NAME environment variable is not set"
    echo "[cade zeppelin] zeppelin service requires declaration of a dependency on spark service, exiting..."
    exit 1
fi
echo "[cade zeppelin] SPARK_SERVICE_NAME ${SPARK_SERVICE_NAME}"

spark_addresses=$(discover_service ${SPARK_SERVICE_NAME})
echo "[cade zeppelin] spark_addresses ${spark_addresses}"

internal_ip=${CONTAINER_IP}
if [ -z "$PUBLIC_HOST_IP" ];
then
    external_ip=${CONTAINER_IP}
else
    external_ip=${PUBLIC_HOST_IP}
fi

# write configuration files discovering cluster layout automatically
zeppelin_to_spark_connection=""
for address in ${spark_addresses}; do
    zeppelin_to_spark_connection="$address:7077,$zeppelin_to_spark_connection"
done

echo "[cade zeppelin] starting zeppelin on ${CONTAINER_IP}"
export ZEPPELIN_PORT=8090
export MASTER="spark://${zeppelin_to_spark_connection}"
mkdir /data/logs || true
export ZEPPELIN_LOG_DIR="/data/logs"
mkdir /data/notebooks || true
export ZEPPELIN_NOTEBOOK_DIR="/data/notebooks"
#export SPARK_HOME=/spark
export SPARK_PUBLIC_DNS="$external_ip"
#export SPARK_LOCAL_IP="$internal_ip"
/opt/zeppelin/bin/zeppelin.sh
