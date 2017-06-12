#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite influxdb] starting..."

config_target=/opt/influxdb/influxdb.conf

echo "[clusterlite influxdb] starting influxdb on ${CONTAINER_IP}"
echo "[clusterlite influxdb] with configuration ${config_target}:"
cat ${config_target}
/opt/influxdb/usr/bin/influxd run -config ${config_target}

