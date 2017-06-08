#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

config_target=/opt/influxdb/influxdb.conf

echo Starting InfluxDB on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
/opt/influxdb/usr/bin/influxd run -config ${config_target}

