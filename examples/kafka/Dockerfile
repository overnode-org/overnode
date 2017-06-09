#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM openjdk:8u131-jre

ADD files /

RUN chmod a+rx /run-kafka.sh && /install-kafka.sh

# 9092: kafka clients

CMD ["/run-kafka.sh"]