---
id: env
title: overnode env
sidebar_label: env
---


Print remote node connection string for docker client.
```md
> overnode [--debug] [--no-color] env --id ID [OPTION] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  --id ID    Target peer node identifier.
  -inline    If specified, prints -H option for docker command line.
             Otherwise, prints the spec for DOCKER_HOST environment variable.
  --ignore-unreachable-nodes
             Skip checking if all target nodes are reachable.
  -h|--help  Print this help.
  ----------------------------------------------------------------------------
```
