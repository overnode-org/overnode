#!/usr/bin/env sh

set -e

yellow_c='\033[0;33m'
gray_c='\033[1;30m'
no_c='\033[0;37m' # white

function set_console_color() {
    echo "$1" >&2
}
function set_console_normal() {
    echo "" >&2
}
trap set_console_normal EXIT

set_console_color 
[ ! -f /tmp/overnode ] || rm /tmp/overnode
wget --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/0.8.4/overnode.sh > /tmp/overnode
chmod u+x /tmp/overnode
set_console_normal

/tmp/overnode --debug version || (echo "overnode download failed" && exit 1)

if [ ! -f /usr/bin/overnode ]
then
    /tmp/overnode install
    mv /tmp/overnode /usr/bin/overnode || (echo "overnode install failed" && exit 1)
else
    if [ $# -eq 0 ]
    then
        set_console_color 
        echo "/usr/bin/overnode file exists already"
        echo "run 'overnode upgrade' instead"
        set_console_normal
    else
        /tmp/overnode install --force
        mv /tmp/overnode /usr/bin/overnode || (echo "overnode upgrade failed" && exit 1)
    fi
fi

