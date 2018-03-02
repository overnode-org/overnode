#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade proxy] starting docker proxy on $(hostname -i)"

socat TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/weave/weave.sock
