---
id: rollover-upgrade
title: Rollover Upgrade for Services
sidebar_label: Rollover Upgrade
---

By default, the Overnode [up](cli-reference/up) command launches all containers in parallel for all nodes and services.

For production life systems, it is very vital to have the safe upgrade procedure, which stops applying changes if a problem is encountered. Usually it is referred as *rollover upgrade* procedure, when containers are updated service-by-service and/or node-by-node.

Overnode supports *rollover upgrade* functionality. Let's explore how to use it.

First of all, a service should have defined health check. Coming back to the previous [echo server example](managing-containers-workflow#launching-a-service) with the added health check option:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        image: ealen/echo-server
        restart: unless-stopped
        ports:
            - 3000:80
        healthcheck:
            test: ["CMD", "true"] # always healthy for demo purposes
            interval: 20s
            timeout: 100s
            retries: 3
            start_period: 10s        
```

Once health check is defined, the [up](cli-reference/up) command can use it and execute rollover upgrade. For example:

```bash
> sudo overnode up --rollover echo
```

This executes controlled serial launch / update of services.
If at least one service argument is specified,
it brings each service up, one by one on each required node.
In the example above we enumerated only one service, `echo`.

If service argument is not specified, it brings all services up on each node, node by node.

Rollover launch / update operation continues iterations only if the launched services / nodes are in healthy state after each iteration.

# Related options

All container state management commands, like [up](cli-reference/up), have got `--serial` argument, which allows to target nodes one by one. This does not do health checking before switching to the next node.

```bash
> sudo overnode up --serial 
``` 

It is also possible to target specific nodes, for example:

```bash
> sudo overnode up --nodes 1,3 
```

And / or specific services, for example:

```bash
> sudo overnode up nginx echo
``` 
