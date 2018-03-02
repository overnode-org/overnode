#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing weave"

WEAVE_VERSION=$(cat /version.txt)

apk add --update curl && \
    curl -L https://github.com/weaveworks/weave/releases/download/v${WEAVE_VERSION}/weave -o /weave && \
    rm -Rf /var/cache/apk/*

echo "Installed weave"
