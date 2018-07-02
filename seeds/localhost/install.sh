#!/bin/bash

set -e

# install specific version of cade
wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/0.7.1/install.sh | sudo sh

# launch the node
cade install --token asdfsdafsda7807sf0sa7f0sad7f0asd8f7sd0a78fsad08f79s7df978 --seeds $(hostname -i) --public-address ::auto --placement default

# launch the services
cade apply --config $(cd "$(dirname "$0")" && pwd)/cade.yaml
