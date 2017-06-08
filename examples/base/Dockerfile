#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM ubuntu:16.04

ADD files /

RUN mv /mirror.list /etc/apt/sources.list.d/mirror.list \
  && mv /sources.list /etc/apt/sources.list \
  && mv /dumb-init_1.2.0_amd64 /sbin/dumb-init \
  && chmod a+rx /run.sh /run-*.sh /sbin/dumb-init \
  && /install-base.sh \
  && /reduce-size.sh

CMD ["/sbin/dumb-init", "/bin/bash", "/run.sh"]
