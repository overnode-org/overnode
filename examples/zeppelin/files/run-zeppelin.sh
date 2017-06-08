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
echo spark_addresses ${spark_addresses}

internal_ip=${CONTAINER_IP}
external_ip=${MACHINE_IP}

# write configuration files discovering cluster layout automatically
zeppelin_to_spark_connection=""
for address in ${spark_addresses}; do
    zeppelin_to_spark_connection="$address:7077,$zeppelin_to_spark_connection"
done

echo Starting Zeppelin on ${CONTAINER_IP}
export ZEPPELIN_PORT=8090
export MASTER="spark://${zeppelin_to_spark_connection}"
mkdir /data/logs || echo ""
export ZEPPELIN_LOG_DIR="/data/logs"
mkdir /data/notebooks || echo ""
export ZEPPELIN_NOTEBOOK_DIR="/data/notebooks" # TODO this data is lost when a container is moved on multi-master cluster
#export SPARK_HOME=/spark
export SPARK_PUBLIC_DNS="$external_ip"
#export SPARK_LOCAL_IP="$internal_ip"
/opt/zeppelin/bin/zeppelin.sh &
zeppelin_pid=$!

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
  echo "Killing $zeppelin_pid"
  kill -TERM $zeppelin_pid
  sleep 10
  kill -KILL $monitor_pid || echo ""
  kill -KILL $zeppelin_pid || echo ""
  exit $exit_code
}
trap _term SIGTERM SIGKILL SIGINT SIGCHLD

wait
