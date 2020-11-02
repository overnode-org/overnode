---
id: central-logging
title: Central Logging with Loki
sidebar_label: Central Logging
---

## Adding the pre-configured stack

When Overnode is installed or upgraded, it also does the same for [Loki](https://grafana.com/oss/loki/) driver for Docker automatically. This enables containers to stream stdout / stderr logs to the Loki server.

First, it is necessary to add the Loki stack to a project:

```bash
> sudo overnode init https://github.com/overnode-org/overnode@examples/infrastructure/loki
```

Adjust the downloaded settings as required. Default settings should work fine for a start. The stack opens `3100` port on localhost interface on each node. The server on the port forwards traffic to the Loki server using the network of a cluster.

The default configuration also enables logs collection from `/var/logs` on each host.

## Configuring logging per containers

To opt in containers to log to Loki, add `logging` section to the required services, like the following:

```yml
...
        logging:
            driver: loki
            options:
                loki-url: "http://localhost:3100/loki/api/v1/push"
                max-size: 20m
                max-file: "5"
...
```

## Browsing logs in Loki using Grafana

To browse logs, add the pre-configured [Grafana](https://grafana.com/grafana/) stack:

```bash
> sudo overnode init https://github.com/overnode-org/overnode@examples/infrastructure/grafana
```

Adjust the downloaded settings as required. Default settings should work fine for a start. The stack opens port `4431` on each host. The server uses self-signed certificate. And the Basic HTTP username/password is configured to `admin`/`admin`.
