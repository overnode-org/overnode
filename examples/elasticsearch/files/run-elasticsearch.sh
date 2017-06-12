#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite elasticsearch] starting..."

if [ -z "$PUBLIC_HOST_IP" ];
then
    internal_ip=${CONTAINER_IP}
else
    internal_ip="0.0.0.0"
fi

if [ -z "$SERVICE_SEEDS" ];
then
    echo "[clusterlite elasticsearch] the service requires declaration of seeds option in the placements section of the configuration, exiting..."
    exit 1
fi

elasticsearch_discovery_hosts="$CONTAINER_IP"
for address in $SERVICE_SEEDS; do
    if [ ${address} != ${CONTAINER_IP} ]
    then
        elasticsearch_discovery_hosts="\"$address\", $elasticsearch_discovery_hosts"
    fi
done

# write configuration files discovering cluster layout automatically
config_target=/opt/elasticsearch/config/elasticsearch.yml
echo "cluster.name: webintrinsics" >> $config_target
echo "node.name: $CONTAINER_IP" >> $config_target
echo "path.data: /data" >> $config_target
echo "network.host: $internal_ip" >> $config_target
echo "discovery.zen.ping.unicast.hosts: [$elasticsearch_discovery_hosts]" >> $config_target
echo "bootstrap.memory_lock: false" >> $config_target

echo "[clusterlite elasticsearch] starting elasticsearch on ${CONTAINER_IP}"
echo "[clusterlite elasticsearch] with configuration ${config_target}:"
cat ${config_target}
/opt/elasticsearch/bin/elasticsearch

