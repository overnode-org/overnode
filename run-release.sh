#!/usr/bin/env sh

# Dependencies:
# - ubuntu 16.04
#   valid hostname, IP interface, DNS, proxy, apt-get configuration
# - internet connection

set -e

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

cd ${DIR}
${DIR}/run-prerequisites.sh
sbt release
