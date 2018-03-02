#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM openjdk:8u131-jre

ADD files /

RUN chmod a+rx /run-spark.sh && /install-spark.sh

# 7077: spark master
# 6066: spark master (REST API)
# 8080: spark master webui
# 7078: spark worker
# 8081: spark worker webui

CMD ["/run-spark.sh"]
