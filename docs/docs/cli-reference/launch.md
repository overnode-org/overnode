---
id: launch
title: overnode launch
sidebar_label: launch
---


Launch the node and / or join a cluster.
```md
> overnode [--debug] [--no-color] launch --id ID [OPTION] --token TOKEN ... [HOST] ...

  Options:   Description:
  ----------------------------------------------------------------------------
  HOST       Peer nodes to connect to in order to form a cluster.
  --id ID    Unique within a cluster node identifier. Number from 1 to 255.
  --token TOKEN
             Same password shared by the nodes in a cluster.
  ----------------------------------------------------------------------------
  -h|--help  Print this help.
  ----------------------------------------------------------------------------
```
