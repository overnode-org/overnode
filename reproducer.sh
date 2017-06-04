#!/usr/bin/env bash

set -e

weave launch \
        --ipalloc-range 10.32.0.0/13 --ipalloc-default-subnet 10.32.0.0/12 \
        --name=::1 --ipalloc-init seed=::1,::2,::3,::4

docker run --name sleep-client -h sleep-client.weave.local -dti \
        --init \
        --net=weave \
        $(weave dns-args) \
        --restart always \
        ubuntu:16.04 \
        sleep 2000

docker run --name sleep-client2 -h sleep-client2.weave.local -dti \
        --init \
        --net=weave --ip=10.40.1.11 \
        $(weave dns-args) \
        --restart always \
        ubuntu:16.04 \
        sleep 2000

docker run --name sleep-client3 -h sleep-client3.weave.local -dti \
        --init \
        --net=weave \
        $(weave dns-args) \
        --restart always \
        ubuntu:16.04 \
        sleep 2000
