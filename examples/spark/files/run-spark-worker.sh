#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

if [ -z "$SPARK_SERVICE_NAME" ]; then
    echo "SPARK_SERVICE_NAME environment variable is required"
    exit 1
fi
echo SPARK_SERVICE_NAME ${SPARK_SERVICE_NAME}

spark_addresses=`discover_service ${SPARK_SERVICE_NAME}`
echo spark_addresses $spark_addresses

internal_ip=$CONTAINER_IP
external_ip=${MACHINE_IP}

# write configuration files discovering cluster layout automatically
config_target=/opt/spark/conf/spark.properties
worker_to_master_connection=""
for address in $spark_addresses; do
    worker_to_master_connection="$address:7077,$worker_to_master_connection"
done

echo Starting Spark on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
export SPARK_NO_DAEMONIZE=true
export SPARK_PUBLIC_DNS="$external_ip"
mkdir /data/logs || echo ""
export SPARK_LOG_DIR="/data/logs"
/opt/spark/sbin/start-slave.sh spark://${worker_to_master_connection} -h ${internal_ip} -p 7078 --webui-port 8081 --work-dir /data --properties-file ${config_target} &
spark_pid=$!

echo Starting Monitor on ${CONTAINER_IP}
spark_addresses_by_comma=`echo ${spark_addresses} | tr " " ","`
${DIR}/run-monitor.sh ${CONTAINER_IP} ${SPARK_SERVICE_NAME} ${spark_addresses_by_comma} &
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
