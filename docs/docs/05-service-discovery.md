---
id: service-discovery
title: Service Discovery
sidebar_label: Service Discovery
---

## Configuring hostname for a container

By default, a container will have a hostname assigned to the name of a service in the domain `.weave.local`. Names in the `.weave.local` domain are searchable by DNS lookup requests within a cluster.

It is possible to configure a different name using `hostname` field for a service configuration, for example:

```yml
version: "3.7"
services:
    echo:
        # change default 'echo.weave.local' to the alternative:
        hostname: echo-server.weave.local
        network_mode: bridge
        image: ealen/echo-server
```

Now all other containers within a cluster may discover IP address(es) of all containers for the example `echo` service by `echo-server` or `echo-server.weave.local` host name.

### Name server address

In general, it is not required to explicitly configure DNS server IP address for processes in containers. However, there are exceptions, for example [HAProxy resolvers setting](https://www.haproxy.com/blog/dns-service-discovery-haproxy/#resolution-in-practice) requires it explicitly configured. This can be done by passing [OVERNODE_BRIDGE_IP](docker-compose-yml-file-description#overnode_bridge_ip) environment variable as an environment variable or as a command line argument for a container. For example:

```yml
version: "3.7"
services:
    haproxy:
        image: haproxy:alpine
        network_mode: bridge
        init: true
        ports:
            - 443:443
        restart: unless-stopped
        environment:
            - NAMESERVER=${OVERNODE_BRIDGE_IP}:53
...
```

### Unique host name

If the same service is placed for multiple nodes and you would like to have unique host names for each container of the same service, you can use [OVERNODE_ID](docker-compose-yml-file-description#overnode_id) environment variable in the hostname value, for example:

```yml
version: "3.7"
services:
    echo:
        # container on the node 1 will have 'echo-1.weave.local' hostname
        hostname: echo-${OVERNODE_ID}.weave.local
        network_mode: bridge
        image: ealen/echo-server
```

## Inspecting DNS records

In order to do DNS lookup in the `.weave.local` domain, use [dns-lookup](cli-reference/dns-lookup) command, for example:

```bash
> sudo overnode dns-lookup echo-server
```

In order to list all of the available DNS records, use [status](cli-reference/status) command:

```bash
> sudo overnode status --dns
```

## Managing DNS records

[dns-add](cli-reference/dns-add) and [dns-remove](cli-reference/dns-remove) commands let you to manipulate DNS records in the the `.weave.local` domain from a command line, for example:

```bash
> sudo overnode dns-add --ips "172.16.1.1,172.16.1.2" --name hostA
> sudo overnode dns-remove --ips "10.78.1.1,10.78.1.2" --name hostA
```

