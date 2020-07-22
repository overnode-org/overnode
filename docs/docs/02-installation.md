---
id: installation
title: Installing and Upgrading the tool
sidebar_label: Installing / Upgrading
---

## Installing the tool

To install the Overnode tool and its dependencies run the following command on each host of a cluster:

```bash
> wget --no-cache -O - https://overnode.org/install | sudo sh
```

The `overnode` is the shell script. It needs `bash` to run. We develop and test with Ubuntu OS, but it works in other environments, where `bash` and GNU core utils, like `grep` and `cut`, are available.

If `docker` is not installed on a host, the Overnode will install it and will take care of upgrading it to a compatible version, when the Overnode is upgraded. If `docker` is installed on a host, the Overnode will automatically opt out from managing docker upgrades.

All other dependencies will be pulled as container images from the Docker Hub.

If installation process is failed, for example, because of the broken internet connection, just rerun the same command.

## Inspecting the version

To inspect the current installation use [version](cli-reference/version) command:

```bash
> sudo overnode version
```

## Upgrading the tool

To upgrade the existing installation to the latest released version run the [upgrade](cli-reference/upgrade) command:

```bash
> sudo overnode upgrade
```

You can choose specific version to upgrade to. See more details in the [command reference](cli-reference/upgrade) manual.

Available releases are published on [Github Releases Page](https://github.com/overnode-org/overnode/releases).

The [upgrade](cli-reference/upgrade) command will download new version of the tool, new dependencies and will upgrade them in correct order. Some of your existing running containers may restart during the upgrade of the tool, depending on the features used by the containers.
