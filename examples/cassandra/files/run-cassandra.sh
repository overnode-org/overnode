#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite cassandra] starting..."

if [ -z "$SERVICE_SEEDS" ];
then
    echo "[clusterlite cassandra] the service requires declaration of seeds option in the placements section of the configuration, exiting..."
    exit 1
fi

# The following vars relate to there counter parts in $CFG
CASSANDRA_CLUSTER_NAME="${CASSANDRA_CLUSTER_NAME:='Docker Swarm Cluster'}"
CASSANDRA_SEEDS=${SERVICE_SEEDS}
CASSANDRA_SEED_PROVIDER="org.apache.cassandra.locator.SimpleSeedProvider"

CASSANDRA_LISTEN_ADDRESS=${CONTAINER_IP}
CASSANDRA_BROADCAST_ADDRESS=${CONTAINER_IP}
CASSANDRA_RPC_ADDRESS=0.0.0.0
if [ -z "$PUBLIC_HOST_IP" ];
then
    CASSANDRA_BROADCAST_RPC_ADDRESS=${CONTAINER_IP}
else
    CASSANDRA_BROADCAST_RPC_ADDRESS=${PUBLIC_HOST_IP}
fi

CASSANDRA_NUM_TOKENS="${CASSANDRA_NUM_TOKENS:-32}"
CASSANDRA_DISK_OPTIMIZATION_STRATEGY="${CASSANDRA_DISK_OPTIMIZATION_STRATEGY:-ssd}"
CASSANDRA_MIGRATION_WAIT="${CASSANDRA_MIGRATION_WAIT:-1}"
CASSANDRA_ENDPOINT_SNITCH="${CASSANDRA_ENDPOINT_SNITCH:-SimpleSnitch}"
CASSANDRA_DC="${CASSANDRA_DC}"
CASSANDRA_RACK="${CASSANDRA_RACK}"
CASSANDRA_RING_DELAY="${CASSANDRA_RING_DELAY:-30000}"
CASSANDRA_AUTO_BOOTSTRAP="${CASSANDRA_AUTO_BOOTSTRAP:-true}"

# Turn off JMX auth
CASSANDRA_OPEN_JMX="${CASSANDRA_OPEN_JMX:-false}"
# send GC to STDOUT
CASSANDRA_GC_STDOUT="${CASSANDRA_GC_STDOUT:-false}"

#
# Patching configuration
#
config_dir=/opt/cassandra/conf
config_target=${config_dir}/cassandra.yaml

# if DC and RACK are set, use GossipingPropertyFileSnitch
if [[ $CASSANDRA_DC && $CASSANDRA_RACK ]]; then
  echo "dc=$CASSANDRA_DC" > $config_dir/cassandra-rackdc.properties
  echo "rack=$CASSANDRA_RACK" >> $config_dir/cassandra-rackdc.properties
  CASSANDRA_ENDPOINT_SNITCH="GossipingPropertyFileSnitch"
fi

# TODO what else needs to be modified
for yaml in \
  broadcast_address \
  broadcast_rpc_address \
  cluster_name \
  listen_address \
  num_tokens \
  rpc_address \
  disk_optimization_strategy \
  endpoint_snitch \
; do
  var="CASSANDRA_${yaml^^}"
  val="${!var}"
  if [ "$val" ]; then
    sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$config_target"
  fi
done

echo "auto_bootstrap: ${CASSANDRA_AUTO_BOOTSTRAP}" >> $config_target

sed -ri 's/- seeds:.*/- seeds: "'"$CASSANDRA_SEEDS"'"/' $config_target
sed -ri 's/- class_name: SEED_PROVIDER/- class_name: '"$CASSANDRA_SEED_PROVIDER"'/' $config_target

# send gc to stdout
if [[ $CASSANDRA_GC_STDOUT == 'true' ]]; then
  sed -ri 's/ -Xloggc:\/var\/log\/cassandra\/gc\.log//' $config_dir/cassandra-env.sh
fi

# enable RMI and JMX to work on one port
echo "JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=$CONTAINER_IP\"" >> $config_dir/cassandra-env.sh

# getting WARNING messages with Migration Service
echo "-Dcassandra.migration_task_wait_in_seconds=${CASSANDRA_MIGRATION_WAIT}" >> $config_dir/jvm.options
echo "-Dcassandra.ring_delay_ms=${CASSANDRA_RING_DELAY}" >> $config_dir/jvm.options


if [[ $CASSANDRA_OPEN_JMX == 'true' ]]; then
  export LOCAL_JMX=no
  sed -ri 's/ -Dcom\.sun\.management\.jmxremote\.authenticate=true/ -Dcom\.sun\.management\.jmxremote\.authenticate=false/' $config_dir/cassandra-env.sh
  sed -ri 's/ -Dcom\.sun\.management\.jmxremote\.password\.file=\/etc\/cassandra\/jmxremote\.password//' $config_dir/cassandra-env.sh
fi

echo "[clusterlite cassandra] CASSANDRA_RPC_ADDRESS ${CASSANDRA_RPC_ADDRESS}"
echo "[clusterlite cassandra] CASSANDRA_NUM_TOKENS ${CASSANDRA_NUM_TOKENS}"
echo "[clusterlite cassandra] CASSANDRA_CLUSTER_NAME ${CASSANDRA_CLUSTER_NAME}"
echo "[clusterlite cassandra] CASSANDRA_LISTEN_ADDRESS ${CASSANDRA_LISTEN_ADDRESS}"
echo "[clusterlite cassandra] CASSANDRA_BROADCAST_ADDRESS ${CASSANDRA_BROADCAST_ADDRESS}"
echo "[clusterlite cassandra] CASSANDRA_BROADCAST_RPC_ADDRESS ${CASSANDRA_BROADCAST_RPC_ADDRESS}"
echo "[clusterlite cassandra] CASSANDRA_DISK_OPTIMIZATION_STRATEGY ${CASSANDRA_DISK_OPTIMIZATION_STRATEGY}"
echo "[clusterlite cassandra] CASSANDRA_MIGRATION_WAIT ${CASSANDRA_MIGRATION_WAIT}"
echo "[clusterlite cassandra] CASSANDRA_ENDPOINT_SNITCH ${CASSANDRA_ENDPOINT_SNITCH}"
echo "[clusterlite cassandra] CASSANDRA_DC ${CASSANDRA_DC}"
echo "[clusterlite cassandra] CASSANDRA_RACK ${CASSANDRA_RACK}"
echo "[clusterlite cassandra] CASSANDRA_RING_DELAY ${CASSANDRA_RING_DELAY}"
echo "[clusterlite cassandra] CASSANDRA_SEEDS ${CASSANDRA_SEEDS}"
echo "[clusterlite cassandra] CASSANDRA_SEED_PROVIDER ${CASSANDRA_SEED_PROVIDER}"
echo "[clusterlite cassandra] CASSANDRA_AUTO_BOOTSTRAP ${CASSANDRA_AUTO_BOOTSTRAP}"

echo "[clusterlite cassandra] starting cassandra on $CONTAINER_IP"
echo "[clusterlite cassandra] with configuration $config_target:"
cat ${config_target}
# TODO assign non-root user for services in all containers
# -R flag is to force Cassandra to accept root user
/opt/cassandra/bin/cassandra -R -f
