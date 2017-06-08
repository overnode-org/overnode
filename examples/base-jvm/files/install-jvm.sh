#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing base-jvm"

apt-get update

JRE_VERSION=8u131-b11-0ubuntu1.16.04.2

# get necessary build and runtime dependencies
# install specific update of java because alpn-boot depends on specific version of java \
apt-get -qq -y install --no-install-recommends \
    openjdk-8-jre-headless=${JRE_VERSION}

echo "Installed base-jvm"
