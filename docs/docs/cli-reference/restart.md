---
id: restart
title: overnode restart
sidebar_label: restart
---


Restart all stopped and running services.
```md
> overnode [--debug] [--no-color] restart [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --timeout TIMEOUT
             Specify a shutdown timeout in seconds. (default: 10).
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
