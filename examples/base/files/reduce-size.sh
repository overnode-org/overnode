#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

#apt-get -y purge curl wget jq localepurge
apt-get clean
rm -rf \
    doc \
    man \
    info \
    locale \
    /var/log/* \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    common-licenses \
    ~/.bashrc \
    /etc/systemd \
    /lib/lsb \
    /lib/udev \
    /usr/share/doc/ \
    /usr/share/doc-base/ \
    /usr/share/man/ \
    /tmp/*
