FROM alpine:latest

ARG ETCD_VERSION=3.1.0

RUN apk add --update ca-certificates openssl tar drill && \
    wget https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    tar xzvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    mv etcd-v${ETCD_VERSION}-linux-amd64/etcd* /bin/ && \
    apk del --purge tar openssl && \
    rm -Rf etcd-v${ETCD_VERSION}-linux-amd64* /var/cache/apk/*

ADD run-etcd.sh /run-etcd.sh
ADD run-etcd-remove.sh /run-etcd-remove.sh

VOLUME /data

# ports available in weave net are 2379 2380

