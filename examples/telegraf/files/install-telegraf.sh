#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing telegraf"

apt-get update
apt-get -qq -y install --no-install-recommends wget
rm -rf /var/lib/apt/lists/* ~/.bashrc

VERSION=$(cat /version.txt)

wget --no-check-certificate -q -O - https://dl.influxdata.com/telegraf/releases/telegraf-${VERSION}_linux_amd64.tar.gz | tar -xzf - -C /opt
cp /telegraf.conf /opt/telegraf

echo "Installed telegraf"
