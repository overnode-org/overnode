#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing chronograf"

VERSION=1.3.0

wget --no-check-certificate -q -O - https://dl.influxdata.com/chronograf/releases/chronograf-${VERSION}_linux_amd64.tar.gz | tar -xzf - -C /opt
mv /opt/chronograf-$VERSION-1 /opt/chronograf

echo "Installed chronograf"
