#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing kafka"

apt-get update
apt-get -qq -y install --no-install-recommends procps libjemalloc1 dnsutils
rm -rf /var/lib/apt/lists/* ~/.bashrc

KAFKA_VERSION=$(cat /version.txt)
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
