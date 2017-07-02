#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

green_c='\033[0;32m'
red_c='\033[0;31m'
gray_c='\033[1;30m'
no_c='\033[0m' # No Color

if [ -z "$1" ];
then
    echo -e "${red_c}[clusterlite proxy] internal error detected, proxy should be invoked with an argument, exiting...${no_c}"
    exit 1
fi

curl --fail -s -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1.json > /dev/null || echo ""
curl --fail -s -X DELETE http://clusterlite-etcd:2379/v2/keys/nodes/$1 > /dev/null

