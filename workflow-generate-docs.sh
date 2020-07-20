#!/usr/bin/env bash

set -e
set -o errexit -o pipefail -o noclobber -o nounset

DIR="$(cd "$(dirname "$0")" && pwd)" # get current file directory

cd ${DIR}

target_dir="./docs/docs/cli-reference"
[ -d ${target_dir} ] || mkdir ${target_dir}

target_ref="./docs/docs/cli-reference.md"
[ ! -f ${target_ref} ] || rm ${target_ref}
    echo """---
id: cli-reference
title: Commands Reference List
sidebar_label: Commands List
---

| Command | Description |
| --------| ----------- |""" >> ${target_ref}

commands="help version install upgrade launch reset prime resume connect forget expose hide env dns-lookup dns-add dns-remove login logout init up down start stop restart pause unpause kill rm pull push ps logs top events config status inspect"
for command in $(echo $commands | tr " " "\n" | sort | tr "\n" " ")
do
    command_descr=$(./overnode.sh --no-color help | grep  "  ${command} " | sed "s/[ ]*${command}[ ]*//")
    echo "| [$command](cli-reference/$command) | $command_descr |" >> ${target_ref}

    [ ! -f ${target_dir}/${command}.md ] || rm ${target_dir}/${command}.md
    echo """---
id: ${command}
title: overnode ${command}
sidebar_label: ${command}
---

""" >> ${target_dir}/${command}.md

    echo ${command_descr} >> ${target_dir}/${command}.md

    echo '```md' >> ${target_dir}/${command}.md
    ./overnode.sh --no-color $command --help >> ${target_dir}/${command}.md
    echo '```' >> ${target_dir}/${command}.md
done