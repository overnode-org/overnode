#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

if [ -z "$ZOOKEEPER_SERVICE_NAME" ]; then
    echo "ZOOKEEPER_SERVICE_NAME environment variable is required"
    exit 1
fi
echo ZOOKEEPER_SERVICE_NAME ${ZOOKEEPER_SERVICE_NAME}

zookeeper_addresses=`discover_service ${ZOOKEEPER_SERVICE_NAME}`
echo zookeeper_addresses $zookeeper_addresses

if [ "$DEVELOPMENT_MODE" == "true" ]
then
    internal_ip="0.0.0.0"
    external_ip=${MACHINE_IP}
else
    internal_ip=$CONTAINER_IP
    external_ip=$CONTAINER_IP
fi

# write configuration files discovering cluster layout automatically
config_target=/opt/kafka/config/server.properties
instance_id=`echo $CONTAINER_IP | cut -d . -f 4`
kafka_to_zookeeper_connection=""
for address in $zookeeper_addresses; do
    kafka_to_zookeeper_connection="$address:2181,$kafka_to_zookeeper_connection"
done
echo "broker.id=$instance_id" >> $config_target
echo "listeners=PLAINTEXT://$internal_ip:9092" >> $config_target
echo "advertised.listeners=PLAINTEXT://$external_ip:9092" >> $config_target
echo "zookeeper.connect=$kafka_to_zookeeper_connection" >> $config_target

echo Starting Kafka on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
/opt/kafka/bin/kafka-server-start.sh ${config_target} &
kafka_pid=$!

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
  echo "Killing $kafka_pid"
  kill -TERM $kafka_pid
  sleep 10
  kill -KILL $monitor_pid || echo ""
  kill -KILL $kafka_pid || echo ""
  exit $exit_code
}
trap _term SIGTERM SIGKILL SIGINT SIGCHLD

wait
