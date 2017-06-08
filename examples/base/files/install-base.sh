#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing base"

apt-get update

apt-get -qq -y install --no-install-recommends \
    procps \
    libjemalloc1 \
    dnsutils \
    localepurge \
    curl \
    wget \
    jq

echo "Installed base"
