#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing spark"

SPARK_VERSION="2.1.0"
SCALA_VERSION="2.11"
HADOOP_VERSION="2.7"

#mirror=$(curl --stderr /dev/null https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred')
mirror="http://apache.mirror.amaze.com.au/"
wget -q -O - ${mirror}spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz | tar -xzf - -C /opt
mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark
mv /spark-log4j.properties /opt/spark/conf/log4j.properties
mv /spark.properties /opt/spark/conf/spark.properties

# add extra jars required for genomes analytics
# http://cdn2.hubspot.net/hubfs/438089/notebooks/Samples/Miscellaneous/Genome_Variant_Analysis_using_k-means_ADAM_and_Apache_Spark.html
mv /*.jar /opt/spark/jars

echo "Installed spark"
