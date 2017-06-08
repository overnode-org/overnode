#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

if [ "$DEVELOPMENT_MODE" == "true" ]
then
    internal_ip="0.0.0.0"
else
    internal_ip=$CONTAINER_IP
fi

elasticsearch_discovery_hosts="$CONTAINER_IP"
for address in $PEER_IPS; do
    if [ $address != $CONTAINER_IP ]
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

echo Starting ElasticSearch on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
/opt/elasticsearch/bin/elasticsearch

