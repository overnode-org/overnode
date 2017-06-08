#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

if [ -z "$INFLUXDB_SERVICE_NAME" ]; then
    echo "INFLUXDB_SERVICE_NAME environment variable is required"
    exit 1
fi
echo INFLUXDB_SERVICE_NAME $INFLUXDB_SERVICE_NAME

config_target=/opt/telegraf/telegraf.conf
sed -i -e "s/_TEMPLATE_NODE_ADDRESS_/$CONTAINER_IP/g" $config_target
sed -i -e "s/_TEMPLATE_INFLUXDB_ADDRESS_/$INFLUXDB_SERVICE_NAME/g" $config_target

echo Starting Telegraf on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
/opt/telegraf/usr/bin/telegraf -config ${config_target} -input-filter docker


