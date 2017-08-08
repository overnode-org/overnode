#!/usr/bin/env sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

version_system=0.6.8
wget --no-cache -O /usr/bin/clusterlite https://raw.githubusercontent.com/webintrinsics/clusterlite/0.6.8/clusterlite.sh
chmod a+x /usr/bin/clusterlite

clusterlite --debug version || (echo "clusterlite installation failed" && exit 1)
