---
id: ps
title: overnode ps
sidebar_label: ps
---


List containers and states of services.
```md
> overnode [--debug] [--no-color] ps [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --quiet    Only display IDs.
  --services Display services.
  --filter KEY=VAL
             Filter services by a property.
  --all      Show all stopped containers,
             including those created by the run command.
  --unhealthy
             Show only those exited abnormally or in unhealthy state.
             '--quiet' option is ignored.
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
