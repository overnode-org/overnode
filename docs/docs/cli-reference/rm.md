---
id: rm
title: overnode rm
sidebar_label: rm
---


Remove stopped containers of services.
```md
> overnode [--debug] [--no-color] rm [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --stop     Stop the containers, if required, before removing.
  --remove-volumes
             Remove any anonymous volumes attached to containers.
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
