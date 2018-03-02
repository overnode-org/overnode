#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

FROM debian:jessie

ADD files /

RUN chmod a+rx /run-telegraf.sh && /install-telegraf.sh

CMD ["/run-telegraf.sh"]
