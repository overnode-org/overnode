#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing influxdb"

apt-get update
apt-get -qq -y install --no-install-recommends wget
rm -rf /var/lib/apt/lists/* ~/.bashrc

VERSION=$(cat /version.txt)

# TODO remove --no-check-certificate in all containers when influxdata fixes the certificate
wget --no-check-certificate -q -O - https://dl.influxdata.com/influxdb/releases/influxdb-${VERSION}_linux_amd64.tar.gz | tar -xzf - -C /opt
mv /opt/influxdb-$VERSION-1 /opt/influxdb
cp /influxdb.conf /opt/influxdb

echo "Installed influxdb"
