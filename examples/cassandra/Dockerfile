#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base-jvm:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-cassandra.sh

# 7000: cassandra interprocess
# 7001: cassandra interprocess (TLS)
# 7199: JMX for cassandra TODO enable JMX for all other services
# 9042: cassandra clients (CQL)
