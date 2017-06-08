#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing telegraf"

VERSION=1.2.1

wget --no-check-certificate -q -O - https://dl.influxdata.com/telegraf/releases/telegraf-${VERSION}_linux_amd64.tar.gz | tar -xzf - -C /opt
cp /telegraf.conf /opt/telegraf

echo "Installed telegraf"
