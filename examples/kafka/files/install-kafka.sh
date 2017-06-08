#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing kafka"

KAFKA_VERSION="0.10.2.1"
SCALA_VERSION="2.12"

#mirror=$(curl --stderr /dev/null https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred')
mirror="http://apache.mirror.amaze.com.au/"
url="${mirror}kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
wget -q "${url}" -O "/tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt
rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka
mv /kafka.properties /opt/kafka/config/server.properties

echo "Installed kafka"
