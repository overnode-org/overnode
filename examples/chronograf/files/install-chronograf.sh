#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing chronograf"

apt-get update
apt-get -qq -y install --no-install-recommends wget
rm -rf /var/lib/apt/lists/* ~/.bashrc

VERSION=$(cat /version.txt)

wget --no-check-certificate -q -O - https://dl.influxdata.com/chronograf/releases/chronograf-${VERSION}_linux_amd64.tar.gz | tar -xzf - -C /opt
mv /opt/chronograf-$VERSION-1 /opt/chronograf

echo "Installed chronograf"
