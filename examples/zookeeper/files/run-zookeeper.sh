#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory
source ${DIR}/run-precheck.sh

# write configuration files discovering cluster layeout automatically
config_target=/opt/zookeeper/conf/zoo.cfg
for address in ${PEER_IPS}; do
    instance_id=`echo ${address} | cut -d . -f 4`
    echo "server.$instance_id=$address:2888:3888" >> ${config_target}
    if [ ${CONTAINER_IP} == ${address} ]
    then
        echo ${instance_id} > /data/myid
    fi
done

echo Starting Zookeeper on ${CONTAINER_IP}
echo with configuration ${config_target}:
cat ${config_target}
/opt/zookeeper/bin/zkServer.sh start-foreground &
zookeeper_pid=$!

echo Starting Monitor on ${CONTAINER_IP}
$DIR/run-monitor.sh $CONTAINER_IP $SERVICE_NAME $PEER_IPS_BY_COMMA &
monitor_pid=$!

set -o monitor
_term() {
  exit_code=0
  echo "Signal received or one of the children finished"
  echo "Killing $monitor_pid"
  # if it can be killed, it means some other child process has terminated,
  # so it becomes an error. Otherwise, it is normal and expected
  kill -TERM $monitor_pid && exit_code=1
  echo "Killing $zookeeper_pid"
  kill -TERM $zookeeper_pid
  sleep 10
  kill -KILL $monitor_pid || echo ""
  kill -KILL $zookeeper_pid || echo ""
  exit $exit_code
}
trap _term SIGTERM SIGKILL SIGINT SIGCHLD

wait
