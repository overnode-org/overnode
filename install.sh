#!/usr/bin/env sh

set -e

yellow_c='\033[0;33m'
gray_c='\033[1;30m'
no_c='\033[0;37m' # white

trap "echo "" >&2" EXIT

echo "" >&2
[ ! -f /tmp/overnode ] || rm /tmp/overnode
wget --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/0.8.5/overnode.sh > /tmp/overnode
chmod u+x /tmp/overnode
echo "" >&2

/tmp/overnode --debug version || (echo "overnode download failed" && exit 1)

if [ ! -f /usr/bin/overnode ]
then
    /tmp/overnode install
    mv /tmp/overnode /usr/bin/overnode || (echo "overnode install failed" && exit 1)
else
    if [ $# -eq 0 ]
    then
        echo "" >&2
        echo "/usr/bin/overnode file exists already"
        echo "run 'overnode upgrade' instead"
        echo "" >&2
    else
        /tmp/overnode install --force
        mv /tmp/overnode /usr/bin/overnode || (echo "overnode upgrade failed" && exit 1)
    fi
fi

