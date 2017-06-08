#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base-jvm:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-spark.sh

# 7077: spark master
# 6066: spark master (REST API)
# 8080: spark master webui
# 7077: spark worker
# 8081: spark worker webui
