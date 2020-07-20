---
id: config
title: overnode config
sidebar_label: config
---


Validate and view the configuration for services.
```md
> overnode [--debug] [--no-color] config [OPTION] ... 

  Options:   Description:
  ----------------------------------------------------------------------------
  --resolve-image-digests
             Pin image tags to digests.
  --no-interpolate
             Don't interpolate environment variables.
  --quiet    Only validate the configuration, don't print anything.
  --services Print the service names, one per line.
  --volumes  Print the volume names, one per line.
  --hash     Print the hashes of the configured services, one per line.
  --nodes NODE,...
             Comma separated list of nodes to target for the action.
             By default, all known nodes are targeted.
  --ignore-unreachable-nodes
             Skip checking if all target nodes are reachable.
  --serial   Execute the command node by node, not in parallel.
  ----------------------------------------------------------------------------
  -h|--help  Print this help.
  ----------------------------------------------------------------------------
```
