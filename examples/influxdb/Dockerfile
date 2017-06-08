#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-influxdb.sh

# 8083: influxdb admin
# 8086: influxdb clients
