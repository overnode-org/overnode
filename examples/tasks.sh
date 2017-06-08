#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

build_image "clusterlite" "base" "2.0.0"
build_image "clusterlite" "base-jvm" "2.0.0"
build_image "clusterlite" "base-python" "2.0.0"
build_image "clusterlite" "base-dotnet" "2.0.0"
build_image "clusterlite" "cassandra" "2.0.0"
build_image "clusterlite" "telegraf" "2.0.0"
build_image "clusterlite" "influxdb" "2.0.0"
build_image "clusterlite" "chronograf" "2.0.0"
build_image "clusterlite" "elasticsearch" "2.0.0"
build_image "clusterlite" "zookeeper" "2.0.0"
build_image "clusterlite" "kafka" "2.0.0"
# build_image "clusterlite" "spark" "2.0.0"
# build_image "clusterlite" "zeppelin" "2.0.0"

# pull_image "weaveworks" "weave" "1.9.3"
# pull_image "weaveworks" "weaveexec" "1.9.3"
# pull_image "weaveworks" "plugin" "1.9.3"
# pull_image "weaveworks" "weavedb" "latest"

docker_login

#push_image "webintrinsics" "base" "2.0.0"
#push_image "webintrinsics" "base-jvm" "2.0.0"
push_image "webintrinsics" "base-python" "2.0.0"
push_image "webintrinsics" "base-dotnet" "2.0.0"
# push_image "webintrinsics" "cassandra" "2.0.0"
# push_image "webintrinsics" "telegraf" "2.0.0"
# push_image "webintrinsics" "influxdb" "2.0.0"
# push_image "webintrinsics" "chronograf" "2.0.0"
# push_image "webintrinsics" "elasticsearch" "2.0.0"
# push_image "webintrinsics" "zookeeper" "2.0.0"
# push_image "webintrinsics" "kafka" "2.0.0"
# push_image "webintrinsics" "spark" "2.0.0"
# push_image "webintrinsics" "zeppelin" "2.0.0"
