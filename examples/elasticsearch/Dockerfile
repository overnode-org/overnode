#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base-jvm:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-elasticsearch.sh

# 9200: elasticsearch clients
