#!/usr/bin/env sh

set -e

[ ! -f /tmp/overnode ] || rm /tmp/overnode
wget -q --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/0.11.6/overnode.sh > /tmp/overnode || (echo "*** overnode download failed" && exit 1)
chmod a+x /tmp/overnode

/tmp/overnode --debug version || (echo "*** overnode download corrupted" && exit 1)

if [ ! -f /usr/bin/overnode ]
then
    /tmp/overnode --debug install || (echo "*** overnode install failed" && exit 1)
    mv /tmp/overnode /usr/bin/overnode || (echo "*** overnode install failed" && exit 1)
else
    if [ $# -eq 0 ]
    then
        /usr/bin/overnode --debug install || (echo "*** overnode install failed" && exit 1)
    else
        /tmp/overnode --debug install --force || (echo "*** overnode upgrade failed" && exit 1)
        mv /tmp/overnode /usr/bin/overnode || (echo "*** overnode upgrade failed" && exit 1)
    fi
fi

