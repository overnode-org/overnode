---
id: monitoring-and-alerting
title: Monitoring by Prometheus
sidebar_label: Monitoring / Alerting
---

## Adding the pre-configured stack

Overnode provides the pre-configured stack for [Prometheus](https://prometheus.io/) and its friends. This enables collection for various host and container level metrics.

To add the stack to a project, run the following:

```bash
> sudo overnode init https://github.com/overnode-org/overnode@examples/infrastructure/prometheus
```

Adjust the downloaded settings as required. Default settings should work fine for a start. Although, the setting for the Alertmanager are likely the first to require your specific settings.

## Browsing metrics using Grafana

To browse metrics, add the pre-configured [Grafana](https://grafana.com/grafana/) stack:

```bash
> sudo overnode init https://github.com/overnode-org/overnode@examples/infrastructure/grafana
```

Adjust the downloaded settings as required. Default settings should work fine for a start. The stack opens port `4431` on each host. The server uses self-signed certificate. And the Basic HTTP username/password is configured to `admin`/`admin`.
There is a pre-configured, automatically provisioned dashboard for browsing metrics.
