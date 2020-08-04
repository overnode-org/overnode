---
id: custom-networking
title: Custom Networking
sidebar_label: Custom Networking
---

## Configuring an IP address for a container

By default, a container will have an IP address assigned automatically out of the pool of available IP addresses: `10.40.0.1` - `10.47.255.254`. Once a container is recreated, it may receive different IP address. A container does not change an IP address if it is restarted.

It is possible to configure a static IP address for a container using [WEAVE_CIDR](docker-compose-yml-file-description#weave_cidr) environment variable. Static IP addresses should be picked from the reserved pool of static IP addresses: `10.32.0.1` - `10.39.255.254`. For example:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        image: ealen/echo-server
        environment:
            WEAVE_CIDR: 10.32.1.1/12
```

:::important
In order to guarantee uniqueness of assigned static IP addresses, it is recommended to use [OVERNODE_CONFIG__*STACK*_ID](docker-compose-yml-file-description#overnode_config__stack_id) and [OVERNODE_ID](docker-compose-yml-file-description#overnode_id) variables in a value for WEAVE_CIDR.
:::

Assuming, [overnode.yml](overnode-yml-file-description) has got a [stack with name `echo`](managing-containers-workflow#launching-a-service), the recommended static IP address configuration would look like the following:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        image: ealen/echo-server
        environment:
            WEAVE_CIDR: 10.32.${OVERNODE_CONFIG_ECHO_ID}.${OVERNODE_ID}/12
```

## Configuring network isolation for a container

Be default all containers can send / receive IP traffic within a cluster in the `10.32.0.0/12` subnet.
It is possible to reduce a subnet for a container using [WEAVE_CIDR](docker-compose-yml-file-description#weave_cidr) environment variable with network mask higher than `12`. For example, `24` below:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        image: ealen/echo-server
        environment:
            WEAVE_CIDR: 10.32.${OVERNODE_CONFIG_ECHO_ID}.${OVERNODE_ID}/24
```

## Inspecting IPAM status

In order to inspect the status of IPAM and a number of assigned / available IP addresses, use [status](cli-reference/status) command:

```bash
> sudo overnode status --ipam
```
