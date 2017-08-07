#!/usr/bin/env sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

DIR="$( cd "$( dirname "$0" )" && pwd )" # get current file directory

version=0.6.5
wget -q --no-cache -O /usr/bin/clusterlite https://raw.githubusercontent.com/webintrinsics/clusterlite/${version}/clusterlite.sh
chmod a+x /usr/bin/clusterlite

clusterlite --debug version || echo ""