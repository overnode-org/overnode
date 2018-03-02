#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM openjdk:8u131-jre

ADD files /

RUN chmod a+rx /run-elasticsearch.sh && /install-elasticsearch.sh

# 9200: elasticsearch clients

CMD ["/run-elasticsearch.sh"]

