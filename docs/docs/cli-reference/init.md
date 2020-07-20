---
id: init
title: overnode init
sidebar_label: init
---


Download configs for services from peer nodes or external repos.
```md
> overnode [--debug] [--no-color] init --restore PROJECT-ID [OPTION] ... [TEMPLATE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  TEMPLATE   Path to git repository and an optional subfolder within
             the repository, separated by '#' character.
             The remote content will be copied to the current directory.
             overnode.yml file will be extended by the remote config.
             Example: https://github.com/overnode-org/overnode#examples/sleep
  --project PROJECT-ID
             Configuration project ID to restore or initialise.
             Default is the name of the current parent directory.
  --restore  Restore the existing configuration from other nodes.
  --force    Force to replace the existing overnode.yml by
             the configuration for PROJECT-ID sourced from peer nodes.
             If --restore option is not defined, reset to empty configuration.
  --ignore-unreachable-nodes
             Skip checking if all target nodes are reachable.
  ----------------------------------------------------------------------------
  -h|--help  Print this help.
  ----------------------------------------------------------------------------
```
