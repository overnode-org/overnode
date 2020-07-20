---
id: pull
title: overnode pull
sidebar_label: pull
---


Pull images associated with services.
```md
> overnode [--debug] [--no-color] pull [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --quiet    Pull without printing progress information.
  --include-deps
             Also pull services declared as dependencies.
  --no-parallel
             Disable parallel pulling.
  --ignore-pull-failures
             Pull what it can and ignore images with pull failures.
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
