#!/usr/bin/env sh

set -e

wget --no-cache -O /tmp/overnode https://raw.githubusercontent.com/avkonst/overnode/${overnode_release_version}/overnode.sh
chmod a+x /tmp/overnode

/tmp/overnode --debug version || (echo "overnode installation failed" && exit 1)
mv /tmp/overnode /usr/bin/overnode
overnode install
