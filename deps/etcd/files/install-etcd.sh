#!/bin/sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "Installing etcd"

ETCD_VERSION=$(cat /version.txt)

apk add --update ca-certificates openssl tar drill && \
    wget https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    tar xzvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    mv etcd-v${ETCD_VERSION}-linux-amd64/etcd* /bin/ && \
    apk del --purge tar openssl && \
    rm -Rf etcd-v${ETCD_VERSION}-linux-amd64* /var/cache/apk/*

echo "Installed etcd"
