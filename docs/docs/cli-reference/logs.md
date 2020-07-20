---
id: logs
title: overnode logs
sidebar_label: logs
---


Display log output from services.
```md
> overnode [--debug] [--no-color] logs [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --follow   Follow log output.
  --timestamps
             Show timestamps.
  --tail LINES
             Number of lines to show from the end of the logs
             for each container.
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
