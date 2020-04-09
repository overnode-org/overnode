#!/bin/bash

# set -e

# echo "Starting zookeeper node ID autodiscovery for docker node '${NODE_ID}'"

# if [[ ! -f /docker ]]
# then
#     echo "/docker file has not been mounted."
#     exit 1
# fi

# /docker config ls | awk '{print $2}' | grep zookeeper-autonode | sort > /zookeeper-autonode-snapshot

# ASSIGNED_ID=$(cat /zookeeper-autonode-snapshot | grep ${NODE_ID} | sed 's/.*-\([0-9]\)[.].*/\1/')

# if [[ -z "${ASSIGNED_ID}" ]]
# then
#     echo "Searching for the next available zookeeper ID"

#     CANDIDATE_ID=1
#     until echo "${NODE_ID} ${NODE_HOSTNAME}" | /docker config create zookeeper-autonode-${CANDIDATE_ID}.lock -
#     do
#         CANDIDATE_ID=$((CANDIDATE_ID+1))
#         if [ "${CANDIDATE_ID}" -eq "6" ]
#         then
#             echo "Unable to assign zookeeper ID within the range from 1 to 5"
#             exit 1
#         fi
#     done
#     echo "${CANDIDATE_ID} ${NODE_HOSTNAME}" | /docker config create zookeeper-autonode-${CANDIDATE_ID}.${NODE_ID} - || {
#         echo "Unexpected failure on creating docker config entry for 'zookeeper-autonode-${CANDIDATE_ID}.${NODE_ID}'"
#         exit 1
#     }
#     echo "Successfully discovered new zookeeper ID '${CANDIDATE_ID}'"
#     ASSIGNED_ID=${CANDIDATE_ID}
    
#     # refresh existing nodes to include recently assigned one
#     /docker config ls | awk '{print $2}' | grep zookeeper-autonode | sort > /zookeeper-autonode-snapshot
# else
#     echo "Successfully discovered existing zookeeper ID '${ASSIGNED_ID}'"
# fi

# ZOOKEEPER_NODES=$(cat /zookeeper-autonode-snapshot | grep -v lock)

# ZOOKEEPER_SERVERS=""
# for zookeeper_node in ${ZOOKEEPER_NODES}; do
#     nid=$(echo $zookeeper_node | sed 's/.*[.]//')
#     iid=$(echo $zookeeper_node | sed 's/.*-\([0-9]\)[.].*/\1/')
#     # ZOOKEEPER_SERVERS="${ZOOKEEPER_SERVERS}server.${iid}=zookeeper-${nid}:2888:3888;2181 "
#     ZOOKEEPER_SERVERS="${ZOOKEEPER_SERVERS}server.${iid}=localhost:2888:3888;2181 "
# done

# echo $ZOOKEEPER_SERVERS

# echo ${ASSIGNED_ID} > /data/myid
# echo "#!/bin/bash
# export ZOO_SERVERS=\"${ZOOKEEPER_SERVERS}\"
# echo \"[zookeeper-autonode] starting with servers: \$ZOO_SERVERS\"
# exec /docker-entrypoint.sh zkServer.sh start-foreground
# " > /data/docker-entrypoint.sh
# chmod a+x /data/docker-entrypoint.sh

while true;
do
    env
    hostname
    hostname -i
    sleep 10
done

# exec "$@"