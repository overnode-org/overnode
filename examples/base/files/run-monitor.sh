#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

if [ -z "$1" ]
  then
    echo "Current container IP address parameter is missing"
    echo "usage: monitor.sh <current-address> <service-dns> <peer-addresses>"
    exit 1
fi

if [ -z "$2" ]
  then
    echo "Service DNS address parameter is missing"
    echo "usage: monitor.sh <current-address> <service-dns> <peer-addresses>"
    exit 1
fi

if [ -z "$3" ]
  then
    echo "Peer addresses parameter is missing"
    echo "usage: monitor.sh <current-address> <service-dns> <peer-addresses>"
    exit 1
fi

current_ip=$1
service_name=$2
peer_addresses_by_comma=$3
peer_addresses=`echo ${peer_addresses_by_comma} | tr "," " "`

while true
do
	echo "Waiting for DNS poll in 1 minute"
    sleep 60

    new_peer_addresses=`dig ${service_name} | grep -A 100000 "ANSWER SECTION" | grep -v ";" | awk '{print $5}' | sort -u`
    new_peer_addresses_by_comma=`echo ${new_peer_addresses} | tr " " ","`
    if [ "$new_peer_addresses_by_comma" != "$peer_addresses_by_comma" ]
    then
        echo "Changes in $service_name detected. Scheduling exit."
        count=0
        offset=0
        for address in ${peer_addresses}; do
            if [ "$address" == "$current_ip" ]
            then
                offset=$count
            fi
            count=$(($count + 1))
        done
        wait_time=$(($offset * 30))
        echo "Scheduled exit in ${wait_time} seconds"
        sleep ${wait_time}
        echo "Exiting"
        exit 0
    fi
done
