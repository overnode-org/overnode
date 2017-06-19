#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "[clusterlite proxy] starting docker proxy on $(hostname -i)"

socat TCP-LISTEN:2375,reuseaddr,fork UNIX-CLIENT:/var/run/weave/weave.sock
