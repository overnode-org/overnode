#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM debian:jessie

ADD files /

RUN chmod a+rx /run-influxdb.sh && /install-influxdb.sh

# 8083: influxdb admin
# 8086: influxdb clients

CMD ["/run-influxdb.sh"]
