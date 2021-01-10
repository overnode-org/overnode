#!/bin/bash
set -e
# This script is meant to test overnode.sh, DEVELOPMENT USE.
# Scrappy thing to just (re-do) overnode up with the echo example

# Assumes you have already set up overnode via the normal method already.

branch=$1 # branch name
runner=$2 # if this is the node doing overnode up etc
pass=$3 # optional
myid=$4 # node id, sometimes optional
echotime=1 # run this thing

if [ -z "$myid" ]; then
    myip=$(hostname -I | cut -d' ' -f 1) # get first ip
    myid=$(rev <<< "$myip" | cut -d. -f -1 | rev) # jc has *.2, *.3 as the node local ipv4 addresses, so automagic can be done from here
fi
if [ -z "$pass" ]; then pass="overnode";fi

if [ "$runner" -eq 1 ] && [ "$echotime" -eq 1 ]; then
    cd ~/overnode/examples/echo
    sudo overnode down
fi

if [ "$runner" -ne 1 ]; then sleep 10;fi # if not main node, hope that the actor stops stuff

sudo overnode reset # will fail if something is running

wget "https://raw.githubusercontent.com/overnode-org/overnode/$branch/overnode.sh"
sudo mv overnode.sh /usr/bin/overnode # overwrite current with new
sudo chmod +x /usr/bin/overnode

if [ "$runner" -eq 1 ]; then
    if [ ! -d ~/overnode ]; then
        git clone https://github.com/overnode-org/overnode.git ~/overnode
        cd ~/overnode
        git checkout "$branch"
    else
        cd ~/overnode
        git pull
    fi

    if [ "$echotime" -eq 1 ]; then # default to just run the echo thing
        cd ~/overnode/examples/echo
        sudo overnode up
    fi
fi