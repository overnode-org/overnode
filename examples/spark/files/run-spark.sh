#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

if [ -z "$ZOOKEEPER_SERVICE_NAME" ]; then
    echo "ZOOKEEPER_SERVICE_NAME environment variable is required"
    exit 1
fi
echo ZOOKEEPER_SERVICE_NAME ${ZOOKEEPER_SERVICE_NAME}

zookeeper_addresses=`discover_service ${ZOOKEEPER_SERVICE_NAME}`
echo zookeeper_addresses $zookeeper_addresses

internal_ip=$CONTAINER_IP
external_ip=${MACHINE_IP}

# write configuration files discovering cluster layout automatically
config_target=/opt/spark/conf/spark.properties
spark_to_zookeeper_connection=""
for address in $zookeeper_addresses; do
    spark_to_zookeeper_connection="$address:2181,$spark_to_zookeeper_connection"
done
# TODO enable zookeeper
#echo "spark.deploy.zookeeper.url=$spark_to_zookeeper_connection" >> $config_target

echo Starting Spark on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
export SPARK_NO_DAEMONIZE=true
export SPARK_PUBLIC_DNS="$external_ip"
mkdir /data/logs || echo ""
export SPARK_LOG_DIR="/data/logs"
/opt/spark/sbin/start-master.sh -h ${internal_ip} -p 7077 --webui-port 8080 --properties-file ${config_target} &
spark_pid=$!

echo Starting Monitor on ${CONTAINER_IP}
${DIR}/run-monitor.sh ${CONTAINER_IP} ${SERVICE_NAME} ${PEER_IPS_BY_COMMA} &
monitor_pid=$!

set -o monitor
_term() {
  exit_code=0
  echo "Signal received or one of the children finished"
  echo "Killing $monitor_pid"
  # if it can be killed, it means some other child process has terminated,
  # so it becomes an error. Otherwise, it is normal and expected
  kill -TERM $monitor_pid && exit_code=1
  echo "Killing $spark_pid"
  kill -TERM $spark_pid
  sleep 10
  kill -KILL $monitor_pid || echo ""
  kill -KILL $spark_pid || echo ""
  exit $exit_code
}
trap _term SIGTERM SIGKILL SIGINT SIGCHLD

wait
