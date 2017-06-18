#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing proxy"

apk add --update && \
    apk add socat curl && \
    rm -Rf /var/cache/apk/*

echo "Installed proxy"
