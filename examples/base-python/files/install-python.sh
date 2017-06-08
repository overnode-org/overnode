#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing base-python"

apt-get update

PYTHON_VERSION=3.5
apt-get -qq -y install --no-install-recommends python${PYTHON_VERSION} python3-pip

echo "Installed base-python"
