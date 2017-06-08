#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base-jvm:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-zookeeper.sh

# 2181: zookeeper clients
# 2888, 3888: zookeeper interprocess
