#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM openjdk:8u131-jre

ADD files /

RUN chmod a+rx /run-zeppelin.sh && /install-zeppelin.sh

# 8090: zeppelin clients
# 4040: spark driver webui

CMD ["/run-zeppelin.sh"]
