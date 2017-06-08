#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing zeppelin"

ZEPPELIN_VERSION="0.7.0"

#mirror=$(curl --stderr /dev/null https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred')
mirror="http://apache.mirror.amaze.com.au/"
wget -q -O - ${mirror}zeppelin/zeppelin-${ZEPPELIN_VERSION}/zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz | tar -xzf - -C /opt
mv /opt/zeppelin-${ZEPPELIN_VERSION}-bin-all /opt/zeppelin

# add extra jars required for genomes analytics
# http://cdn2.hubspot.net/hubfs/438089/notebooks/Samples/Miscellaneous/Genome_Variant_Analysis_using_k-means_ADAM_and_Apache_Spark.html
cp /*.jar /opt/zeppelin/interpreter/spark
mv /*.jar /opt/zeppelin/interpreter/spark/dep

echo "Installed zeppelin"
