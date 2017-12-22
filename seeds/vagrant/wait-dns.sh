#!/usr/bin/env sh

#
# The script waits for currect hostname resolution for the current host
#

set -e

echo "[wait-dns] identifying assigned hostname and address..."

this_host=$(hostname)
echo "[wait-dns] machine hostname: ${this_host}"

default_if=$(ip route | grep default | awk '{print $NF}')
echo "[wait-dns] assigned network: ${default_if}"
default_ip=$(ip route | grep ${default_if} | awk '{print $NF}' | tail -1)
echo "[wait-dns] assigned address: ${default_ip}"

resolved_ip=$(getent hosts ${this_host} | awk '{print $1}')

while [ ${resolved_ip} != ${default_ip} ]; do
    echo "[wait-dns] resolved address: ${resolved_ip}, waiting for correct hostname resolution..."
    sleep 20
    resolved_ip=$(getent hosts ${this_host} | awk '{print $1}')
done
echo "[wait-dns] resolved address: ${resolved_ip}"
