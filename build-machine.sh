#!/bin/bash

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

# Dependencies:
# - ubuntu 16.04 or CentOs 7.1 machine with
#   valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
# - internet connection

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # get current file directory

apt-get update
apt-get -qq -y install --no-install-recommends openjdk-8-jre-headless unzip jq

