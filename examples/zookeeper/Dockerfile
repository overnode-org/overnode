#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM openjdk:8u131-jre

ADD files /

RUN chmod a+rx /run-zookeeper.sh && /install-zookeeper.sh

# 2181: zookeeper clients
# 2888, 3888: zookeeper interprocess

CMD ["/run-zookeeper.sh"]
