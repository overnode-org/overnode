---
id: up
title: overnode up
sidebar_label: up
---


Build, (re)create, and start containers for services.
```md
> overnode [--debug] [--no-color] up [OPTION] ... [SERVICE] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  SERVICE    List of services to target for the action.
  --attach   Once up and running attach to the logging output from containers.
  --remove-orphans
             Remove containers for services not defined in
             the configuration files.
  --quiet-pull
             Pull without printing progress information.
  --force-recreate
             Recreate containers even if their configuration
             and image haven't changed.
  --no-recreate
             If containers already exist, don't recreate
             them. Incompatible with --force-recreate.
  --no-start Don't start the services after creating them.
  --timeout TIMEOUT
             Use this timeout in seconds for container
             shutdown when attached or when containers are
             already running. (default: 10)
  --rollover Execute controlled serial launch of services.
             If at least one SERVICE argument is specified,
             brings each SERVICE up, one by one on each required node.
             If SERVICE argument is not specified,
             brings each node up, one by one.
             Continues iterations only if the launched services / nodes
             are in healthy state.
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
