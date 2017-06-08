FROM alpine:latest

ARG WEAVE_VERSION=1.9.7

RUN apk add --update curl && \
    curl -L https://github.com/weaveworks/weave/releases/download/v1.9.7/weave -o /weave && \
    rm -Rf /var/cache/apk/*

CMD cat /weave
