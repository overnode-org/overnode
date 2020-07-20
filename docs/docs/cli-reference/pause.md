---
id: pause
title: overnode pause
sidebar_label: pause
---


Pause running containers of services.
```md
> overnode [--debug] [--no-color] pause [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
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
