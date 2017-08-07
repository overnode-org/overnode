#!/usr/bin/env bash

# Dependencies:
# - ubuntu 16.04
#   valid hostname, IP interface, DNS, proxy, apt-get configuration
# - internet connection

set -e

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

${DIR}/run-prerequisites.sh

# Given $1 and $2 as semantic version numbers like 3.1.2, return [ $1 < $2 ]
version_lt() {
    VERSION_MAJOR=${1%.*.*}
    REST=${1%.*} VERSION_MINOR=${REST#*.}
    VERSION_PATCH=${1#*.*.}

    MIN_VERSION_MAJOR=${2%.*.*}
    REST=${2%.*} MIN_VERSION_MINOR=${REST#*.}
    MIN_VERSION_PATCH=${2#*.*.}

    if [ "$1" == "$2" ] ; then
        return 0
    fi

    if [ \( "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" \) -o \
        \( "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a \
        \( "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" -o \
        \( "$VERSION_MINOR" -eq "$MIN_VERSION_MINOR" -a \
        \( "$VERSION_PATCH" -lt "$MIN_VERSION_PATCH" \) \) \) \) ] ; then
        return 0
    fi
    return 1
}

# move to working directory
cd ${DIR}

# check repo status
if [ "$(git status | grep git | grep -v push | wc -l)" -ne "0" ]
then
    echo "Error: local directory contains dirty files OR not in sync with remote repository"
    exit 1
fi

# extract and check release version

echo "Info: extracting version"

line=$(head -20 ${DIR}/clusterlite.sh | grep version_system)
current_version=${line/version_system=/}

line=$(head -20 ${DIR}/install.sh | grep version_system)
latest_version=${line/version_system=/}

echo "Info: checking version"

if version_lt ${current_version} ${latest_version} ; then
    echo "Error: current release version $current_version should be greater than latest released $latest_version"
    exit 1
fi

# build and push containers
${DIR}/run-publish.sh --push

echo "Info: releasing version ${current_version}"

export clusterlite_release_version="$current_version"
envsubst < "install.sh.template" > "install.sh"

git add "install.sh"
git commit -m "Release ${current_version}"
git tag ${current_version}
git push --tags

echo "Done: version ${current_version} has been released"
