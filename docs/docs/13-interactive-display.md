---
id: interactive-display
title: Interactive Display by Weavescope
sidebar_label: Interactive Display
---

## Adding the pre-configured stack

Overnode provides the pre-configured stack for [Weavescope](https://www.weave.works/oss/scope/). This is an amazing interactive browser which brings ultimate visibility to your cluster.

In order to add the stack to a project, run the following:

```bash
> sudo overnode init https://github.com/overnode-org/overnode@examples/infrastructure/weavescope
```

The stack will open `4430` port on each host in a cluster. The server uses self-signed certificate. And the Basic HTTP username/password is configured to `admin`/`admin`. These are the main configurations which you may want to change. All other settings should work automatically well.
