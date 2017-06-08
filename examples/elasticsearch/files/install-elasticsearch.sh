#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing elasticsearch"

VERSION=5.4.0

wget -q -O - https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$VERSION.tar.gz | tar -xzf - -C /opt
mv /opt/elasticsearch-$VERSION /opt/elasticsearch

echo "Installed elasticsearch"
