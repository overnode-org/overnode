---
id: docker-compose-yml-file-description
title: Referenced Compose files description
sidebar_label: referenced .yml files
---

The format and all the options of these files are documented in the [Docker Compose documentation](https://docs.docker.com/compose/compose-file/).

Overnode adds the following automatic environment variables in addition to the variables defined in the [.env](dotenv-file-description) file.

#### OVERNODE_ID

Unique [Node Identifier](managing-cluster#concepts), where a referenced file is applied.

#### OVERNODE_TARGET

Hostname of a [Node](managing-cluster#concepts), where a referenced file is applied.

#### OVERNODE_PROJECT_ID

Value of the `id` property from the [overnode.yml](overnode-yml-file-description) file.

#### OVERNODE_ETC

Location of uploaded project files on each node. Currently, it is a sub-directory within `/etc/overnode/volume/` directory.

#### OVERNODE_BRIDGE_IP

The IP address of a Docker bridge network interface.

#### OVERNODE_CONFIG__*STACK*_ID

A set of automatically assigned unique identifiers. A variable is defined per every stack configured in the [overnode.yml](overnode-yml-file-description) file. *STACK* is a name of a stack.
