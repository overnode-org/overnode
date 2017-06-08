#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing cassandra"

VERSION=3.10

#MIRROR=$(curl --stderr /dev/null https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred')
MIRROR="http://apache.mirror.amaze.com.au/"

wget -q -O - $MIRROR/cassandra/$VERSION/apache-cassandra-$VERSION-bin.tar.gz | tar -xzf - -C /opt
mv /opt/apache-cassandra-$VERSION /opt/cassandra
mv /cassandra.yaml /opt/cassandra/conf

echo "Installed cassandra"
