#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite kafka] starting..."

function discover_service()
{
    service_name=$1
    local addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    local addresses_by_comma=`echo ${addresses} | tr " " ","`
    echo "$addresses"
}

if [ -z "$ZOOKEEPER_SERVICE_NAME" ]; then
    echo "[clusterlite kafka] ZOOKEEPER_SERVICE_NAME environment variable is not set"
    echo "[clusterlite kafka] kafka service requires declaration of a dependency on zookeeper service, exiting..."
    exit 1
fi
echo "[clusterlite kafka] ZOOKEEPER_SERVICE_NAME ${ZOOKEEPER_SERVICE_NAME}"

zookeeper_addresses=$(discover_service ${ZOOKEEPER_SERVICE_NAME})
echo "[clusterlite kafka] zookeeper_addresses $zookeeper_addresses"

if [ -z "$PUBLIC_HOST_IP" ];
then
    internal_ip=${CONTAINER_IP}
    external_ip=${CONTAINER_IP}
else
    internal_ip="0.0.0.0"
    external_ip=${PUBLIC_HOST_IP}
fi

# write configuration files discovering cluster layout automatically
config_target=/opt/kafka/config/server.properties
kafka_to_zookeeper_connection=""
for address in ${zookeeper_addresses}; do
    kafka_to_zookeeper_connection="$address:2181,$kafka_to_zookeeper_connection"
done
echo "broker.id=$NODE_ID" >> $config_target
echo "listeners=PLAINTEXT://$internal_ip:9092" >> $config_target
echo "advertised.listeners=PLAINTEXT://$external_ip:9092" >> $config_target
echo "zookeeper.connect=$kafka_to_zookeeper_connection" >> $config_target
echo "offsets.topic.replication.factor=${OFFSETS_TOPIC_REPLICATION_FACTOR:-1}" >> $config_target

echo "[clusterlite kafka] starting kafka on ${CONTAINER_IP}"
echo "[clusterlite kafka] with configuration ${config_target}:"
cat ${config_target}
/opt/kafka/bin/kafka-server-start.sh ${config_target}
