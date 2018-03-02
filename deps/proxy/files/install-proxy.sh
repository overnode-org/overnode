#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing proxy"

apk add --update && \
    apk add socat curl jq && \
    rm -Rf /var/cache/apk/*

echo "Installed proxy"
