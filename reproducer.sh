#!/usr/bin/env bash

set -e

weave launch \
        --name=::1 --ipalloc-init seed=::1,::2,::3,::4

docker run --name sleep-client -h sleep-client.weave.local -dti \
        --init \
        --net=weave \
        $(weave dns-args) \
        --restart always \
        ubuntu:16.04 \
        sleep 2000

docker ps

sleep 5

service docker restart

sleep 5

docker ps
