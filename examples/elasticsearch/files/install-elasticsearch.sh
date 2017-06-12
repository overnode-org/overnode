#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing elasticsearch"

apt-get update
apt-get -qq -y install --no-install-recommends procps libjemalloc1
rm -rf /var/lib/apt/lists/* ~/.bashrc

VERSION=$(cat /version.txt)

wget -q -O - https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$VERSION.tar.gz | tar -xzf - -C /opt
mv /opt/elasticsearch-$VERSION /opt/elasticsearch

echo "Installed elasticsearch"
