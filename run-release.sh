#!/usr/bin/env bash

set -e

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

cd ${DIR}

# check repo status
if [ "$(git status | grep git | grep -v push | wc -l)" -ne "0" ]
then
    echo "Error: local directory contains dirty files OR not in sync with remote repository"
    exit 1
fi

echo "Info: extracting version"

line=$(head -26 ${DIR}/overnode.sh | grep version_system)
current_version=${line/version_system=/}

line=$(head -26 ${DIR}/overnode.sh | grep version_system)
latest_version=${line/version_system=/}

echo "Info: releasing version ${current_version}"

export overnode_release_version="$current_version"
envsubst < "install.sh.template" > "install.sh"

git add "install.sh"
git commit -m "Release ${current_version}"
git tag ${current_version}
git push --tags
git push

echo "Done: version ${current_version} has been released"
