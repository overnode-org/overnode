#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite spark-worker] starting..."

function discover_service()
{
    service_name=$1
    local addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    local addresses_by_comma=`echo ${addresses} | tr " " ","`
    echo "$addresses"
}

if [ -z "$SPARK_SERVICE_NAME" ]; then
    echo "[clusterlite spark-worker] SPARK_SERVICE_NAME environment variable is not set"
    echo "[clusterlite spark-worker] spark-worker service requires declaration of a dependency on spark service, exiting..."
    exit 1
fi
echo "[clusterlite spark-worker] SPARK_SERVICE_NAME ${SPARK_SERVICE_NAME}"

spark_addresses=$(discover_service ${SPARK_SERVICE_NAME})
echo "[clusterlite spark-worker] spark_addresses $spark_addresses"

internal_ip=${CONTAINER_IP}
if [ -z "$PUBLIC_HOST_IP" ];
then
    external_ip=${CONTAINER_IP}
else
    external_ip=${PUBLIC_HOST_IP}
fi

# write configuration files discovering cluster layout automatically
config_target=/opt/spark/conf/spark.properties
worker_to_master_connection=""
for address in $spark_addresses; do
    worker_to_master_connection="$address:7077,$worker_to_master_connection"
done

echo "[clusterlite spark-worker] starting spark on ${CONTAINER_IP}"
echo "[clusterlite spark-worker] with configuration ${config_target}:"
cat ${config_target}
export SPARK_NO_DAEMONIZE=true
export SPARK_PUBLIC_DNS="$external_ip"
mkdir /data/logs || echo ""
export SPARK_LOG_DIR="/data/logs"
/opt/spark/sbin/start-slave.sh spark://${worker_to_master_connection} -h ${internal_ip} -p 7078 --webui-port 8081 --work-dir /data --properties-file ${config_target}
