#!/usr/bin/env sh

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

version_system=0.7.0
wget --no-cache -O /usr/bin/cade https://raw.githubusercontent.com/cadeworks/cade/0.7.0/cade.sh
chmod a+x /usr/bin/cade

cade --debug version || (echo "cade installation failed" && exit 1)
