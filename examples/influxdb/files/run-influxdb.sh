#!/bin/bash

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade influxdb] starting..."

config_target=/opt/influxdb/influxdb.conf

echo "[cade influxdb] starting influxdb on ${CONTAINER_IP}"
echo "[cade influxdb] with configuration ${config_target}:"
cat ${config_target}
/opt/influxdb/usr/bin/influxd run -config ${config_target}

