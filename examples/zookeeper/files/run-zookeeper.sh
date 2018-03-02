#!/bin/bash

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade zookeeper] starting..."

# write configuration files discovering cluster layout automatically
config_target=/opt/zookeeper/conf/zoo.cfg
for address in ${SERVICE_SEEDS//,/ }; do
    instance_id=`echo ${address} | cut -d . -f 4`
    echo "server.$instance_id=$address:2888:3888" >> ${config_target}
    if [[ "${CONTAINER_IP}" == "${address}" ]]
    then
        echo ${instance_id} > /data/myid
    fi
done
if [ ! -f /data/myid ]; then
    echo "[cade zookeeper] it seems more zookeeper instances placed than seeds specified for the service"
    echo "[cade zookeeper] current container IP: $CONTAINER_IP"
    echo "[cade zookeeper] current service seeds: $SERVICE_SEEDS"
    echo "[cade zookeeper] exiting..."
    exit 1
fi

echo "[cade zookeeper] starting zookeeper on $CONTAINER_IP"
echo "[cade zookeeper] with configuration $config_target:"
cat ${config_target}
/opt/zookeeper/bin/zkServer.sh start-foreground
