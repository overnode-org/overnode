#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM debian:jessie

ADD files /

RUN chmod a+rx /run-chronograf.sh && /install-chronograf.sh

# 8888: chronograf clients

CMD ["/run-chronograf.sh"]
