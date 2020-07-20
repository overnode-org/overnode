---
id: kill
title: overnode kill
sidebar_label: kill
---


Force running containers to stop by sending a signal.
```md
> overnode [--debug] [--no-color] kill [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --signal SIGNAL
             SIGNAL to send to the container. Default signal is SIGKILL.
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
