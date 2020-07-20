---
id: status
title: overnode status
sidebar_label: status
---


View the state of the node, connections, dns, ipam, endpoints.
```md
> overnode [--debug] [--no-color] status [OPTION] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  --targets|--peers|--connections|--dns|--ipam|--endpoints
             Various toogle flags allowing to pick specific components status.
             By default, prints the status for all components.
  ----------------------------------------------------------------------------
  -h|--help  Print this help.
  ----------------------------------------------------------------------------
```
