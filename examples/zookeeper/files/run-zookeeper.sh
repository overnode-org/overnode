#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite zookeeper] starting..."

# write configuration files discovering cluster layout automatically
config_target=/opt/zookeeper/conf/zoo.cfg
for address in ${SERVICE_SEEDS}; do
    instance_id=`echo ${address} | cut -d . -f 4`
    echo "server.$instance_id=$address:2888:3888" >> ${config_target}
    if [ ${CONTAINER_IP} == ${address} ]
    then
        echo ${instance_id} > /data/myid
    fi
done
if [ ! -f /data/myid ]; then
    echo "[clusterlite zookeeper] it seems more zookeeper instances placed than seeds specified for the service"
    echo "[clusterlite zookeeper] current container IP: $CONTAINER_IP"
    echo "[clusterlite zookeeper] current service seeds: $SERVICE_SEEDS"
    echo "[clusterlite zookeeper] exiting..."
    exit 1
fi

echo "[clusterlite zookeeper] starting zookeeper on $CONTAINER_IP"
echo "[clusterlite zookeeper] with configuration $config_target:"
cat ${config_target}
/opt/zookeeper/bin/zkServer.sh start-foreground
