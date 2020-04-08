#!/usr/bin/env sh

set -e

wget --no-cache -O /tmp/overnode https://raw.githubusercontent.com/avkonst/overnode/0.8.0/overnode.sh
chmod a+x /tmp/overnode

/tmp/overnode --debug version || (echo "overnode download failed" && exit 1)

if [ ! -f /usr/bin/overnode ]
then
    overnode install
    mv /tmp/overnode /usr/bin/overnode || (echo "overnode install failed" && exit 1)
else
    if [ $# -eq 0 ]
    then
        echo "/usr/bin/overnode file exists already"
        echo "run this script with --force flag to initiate the upgrade"
    else
        /tmp/overnode install --force
        mv /tmp/overnode /usr/bin/overnode || (echo "overnode upgrade failed" && exit 1)
    fi
fi

