#!/bin/bash

set -e

# install specific version of clusterlite
wget -q --no-cache -O - https://raw.githubusercontent.com/webintrinsics/clusterlite/0.6.17/install.sh | sudo sh

# launch the node
clusterlite install --token asdfsdafsda7807sf0sa7f0sad7f0asd8f7sd0a78fsad08f79s7df978 --seeds $(hostname -i) --public-address ::auto --placement default

# launch the services
clusterlite apply --config $(cd "$(dirname "$0")" && pwd)/clusterlite.yaml
