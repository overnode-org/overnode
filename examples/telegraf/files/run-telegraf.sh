#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade telegraf] starting..."

if [ -z "$INFLUXDB_SERVICE_NAME" ]; then
    echo "[cade telegraf] INFLUXDB_SERVICE_NAME environment variable is not set"
    echo "[cade telegraf] telegraf service requires declaration of a dependency on influxdb service, exiting..."
    exit 1
fi
echo "[cade telegraf] INFLUXDB_SERVICE_NAME $INFLUXDB_SERVICE_NAME"

config_target=/opt/telegraf/telegraf.conf
sed -i -e "s/_TEMPLATE_NODE_ADDRESS_/$CONTAINER_IP/g" $config_target
sed -i -e "s/_TEMPLATE_INFLUXDB_ADDRESS_/$INFLUXDB_SERVICE_NAME/g" $config_target

echo "[cade telegraf] starting telegraf on ${CONTAINER_IP}"
echo "[cade telegraf] with configuration ${config_target}:"
cat ${config_target}
/opt/telegraf/usr/bin/telegraf -config ${config_target} -input-filter docker


