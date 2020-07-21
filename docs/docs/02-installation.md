---
id: installation
title: Installation and Upgrade
sidebar_label: 1. Installation / Upgrade
---

## Installing the tool

To install the tool and its dependencies run the following command on each host of a cluster:

```bash
> wget --no-cache -O - https://overnode.org/install | sudo sh
```

The overnode is the shell script. All of the dependencies, except docker, will be pulled as container images from the Docker Hub. If docker is installed on a host, the installer will not install it and will automatically opt out from managing docker upgrades in the future.

If installation failed, for example, because of the broken internet connection, just rerun the same command.

## Version checking

To verify the current installation run the following command:

```bash
> sudo overnode version
```

## Upgrading the tool

To upgrade the existing installation run the following:

```bash
> sudo overnode upgrade
```

You can choose specific version to upgrade to. See more details in the [command reference](cli-reference/upgrade) manual.

Available releases are published on [Github Releases Page](https://github.com/overnode-org/overnode/releases).

The upgrade command will download new version of the tool, new dependencies and will upgrade them in correct order. Some of your existing running containers may restart during the upgrade of the tool, depending on the features used by the containers.


