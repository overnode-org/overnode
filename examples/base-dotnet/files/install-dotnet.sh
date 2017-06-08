#!/bin/sh

#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

set -e

echo "Installing base-dotnet"

# see details here: https://www.microsoft.com/net/download/linux
# BUT IT DOES NOT WORK (the script throws errors)
# DOTNET_VERSION=v1
# curl -sSL https://dot.net/${DOTNET_VERSION}/dotnet-install.sh > /install-dotnet-ms.sh
# chmod a+x /install-dotnet-ms.sh
# /install-dotnet-ms.sh --shared-runtime

# alternative:
# see details here https://github.com/dotnet/core/blob/master/release-notes/download-archives/1.1.1-download.md
wget --no-check-certificate -q -O - https://go.microsoft.com/fwlink/?LinkID=843432 | tar -xzf - -C /usr/bin

echo "Installed base-dotnet"
