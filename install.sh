#!/usr/bin/env sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

#clusterlite_release_version=0.6.5
#wget --no-cache -O /usr/bin/clusterlite https://raw.githubusercontent.com/webintrinsics/clusterlite/${clusterlite_release_version}/clusterlite.sh
#chmod a+x /usr/bin/clusterlite

#clusterlite --debug version || (echo "clusterlite installation failed" && exit 1)

export clusterlite_release_version="aaaa"
envsubst < "install.sh.template" > "install.sh.versioned"