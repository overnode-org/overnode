---
id: down
title: overnode down
sidebar_label: down
---


Stop and remove containers, networks, volumes, and images.
```md
> overnode [--debug] [--no-color] down [OPTION] ... 

  Options:   Description:
  ----------------------------------------------------------------------------
  --remove-orphans
             Remove containers for services not defined in
             the configuration files.
  --remove-images
             Remove images used by the services.
  --remove-volumes
             Remove named volumes declared in the 'volumes'
             section of the Compose file and anonymous volumes
             attached to containers.
  --timeout TIMEOUT
             Specify a shutdown timeout in seconds. (default: 10)
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
