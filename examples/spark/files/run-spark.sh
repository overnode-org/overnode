#!/bin/bash

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade spark] starting..."

function discover_service()
{
    service_name=$1
    local addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    local addresses_by_comma=`echo ${addresses} | tr " " ","`
    echo "$addresses"
}

if [ -z "$ZOOKEEPER_SERVICE_NAME" ]; then
    echo "[cade spark] ZOOKEEPER_SERVICE_NAME environment variable is not set"
    echo "[cade spark] spark service requires declaration of a dependency on zookeeper service, exiting..."
    exit 1
fi
echo "[cade spark] ZOOKEEPER_SERVICE_NAME ${ZOOKEEPER_SERVICE_NAME}"

zookeeper_addresses=$(discover_service ${ZOOKEEPER_SERVICE_NAME})
echo "[cade spark] zookeeper_addresses $zookeeper_addresses"

internal_ip=${CONTAINER_IP}
if [ -z "$PUBLIC_HOST_IP" ];
then
    external_ip=${CONTAINER_IP}
else
    external_ip=${PUBLIC_HOST_IP}
fi

# write configuration files discovering cluster layout automatically
config_target=/opt/spark/conf/spark.properties
spark_to_zookeeper_connection=""
for address in $zookeeper_addresses; do
    spark_to_zookeeper_connection="$address:2181,$spark_to_zookeeper_connection"
done
# TODO enable zookeeper
#echo "spark.deploy.zookeeper.url=$spark_to_zookeeper_connection" >> $config_target

echo "[cade spark] starting spark on ${CONTAINER_IP}"
echo "[cade spark] with configuration ${config_target}:"
cat ${config_target}
export SPARK_NO_DAEMONIZE=true
export SPARK_PUBLIC_DNS="$external_ip"
mkdir /data/logs || true
export SPARK_LOG_DIR="/data/logs"
/opt/spark/sbin/start-master.sh -h ${internal_ip} -p 7077 --webui-port 8080 --properties-file ${config_target}

