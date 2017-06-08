#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing zookeeper"

VERSION=3.4.10

#MIRROR=$(curl --stderr /dev/null https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred')
MIRROR="http://apache.mirror.amaze.com.au/"

wget -q -O - $MIRROR/zookeeper/zookeeper-$VERSION/zookeeper-$VERSION.tar.gz | tar -xzf - -C /opt
mv /opt/zookeeper-$VERSION /opt/zookeeper
cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg
cp /zookeeper.properties /opt/zookeeper/conf/zoo.cfg

echo "Installed zookeeper"
