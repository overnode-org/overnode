# clusterlite
Simple but powerful alternative to Kubernetes and Docker Swarm

TBD

## Help

```
> clusterlite [--debug] <action> [OPTIONS]

    Actions / Options:                      | Description:
    -------------------------------------------------------------------------------------------------------------
    help                                   => Print this help information.
    version                                => Print version information.
    -------------------------------------------------------------------------------------------------------------
    install                                => Install clusterlite node on the current host and join the cluster.
      --token <cluster-wide-token>          | Token should be the same for all nodes joining the cluster.
      --seeds <host1,host2,...>             | 3-5 seeds are recommended for high-availability and reliability.
                                            | Hosts should be private IP addresses or valid DNS host names.
                                            | If 1 host is planned initially, initialize as the following:
                                            |   host1$ clusterlite install --seeds host1
                                            | When 2 more hosts are added later, initialize as the following:
                                            |   host2$ clusterlite install --seeds host1,host2,host3
                                            |   host3$ clusterlite install --seeds host1,host2,host3
                                            | If all 3 hosts are planned initially, initialize as the following:
                                            |   host1$ clusterlite install --seeds host1,host2,host3
                                            |   host2$ clusterlite install --seeds host1,host2,host3
                                            |   host3$ clusterlite install --seeds host1,host2,host3
                                            | If a host is joining as non seed host, initialize as the following:
                                            |   host4$ clusterlite install --seeds host1,host2,host3
                                            | WARNING: seeds order should be the same on all joining hosts!
      [--volume /var/lib/clusterlite]       | Directory where stateful services will persist data.
      [--public-address]                    | Public IP address of the host, if exists and requires exposure.
      [--placement default]                 | Role allocation for a node. A node schedules services
                                            | according to the matching placement
                                            | defined in the configuration file set via 'apply' action.
    uninstall                              => Destroy processes/containers, leave the cluster and remove data.
    -------------------------------------------------------------------------------------------------------------
    info                                   => Show cluster-wide information, like IDs of nodes.
    -------------------------------------------------------------------------------------------------------------
    login                                  => Provide credentials to download images from private repositories.
      --username <username>                 | Docker registry username.
      --password <password>                 | Docker registry password.
      [--registry registry.hub.docker.com]  | Address of docker registry to login to.
                                            | If you have got multiple different registries,
                                            | execute 'login' action multiple times.
                                            | Credentials can be also different for different registries.
    logout                                 => Removes credentials for a registry
      [--registry registry.hub.docker.com]  | Address of docker registry to logout from.
    -------------------------------------------------------------------------------------------------------------
    plan                                   => Review what current or new configuration requires to apply.
      [--config /path/to/yaml/file]         | The same as for 'apply' action.
    apply                                  => Apply current or new configuration and provision services.
      [--config /path/to/yaml/file]         | Configuration file for the cluster, which defines
                                            | what containers to create and where to launch them.
                                            | If it is not defined, the latest applied is used.
    show                                   => Show current status of created containers / services.
    destroy                                => Terminate and destroy all containers / services in the cluster.
    -------------------------------------------------------------------------------------------------------------
    docker                                 => Run docker command against one or multiple nodes of the cluster.
      [--nodes 1,2,..]                      | Comma separated list of IDs of nodes. If absent, applies to all.
      <docker-command> [docker-options]     | Valid docker command and options. For example:
                                            | - List running containers on node 1:
                                            |   host1$ clusterlite docker --nodes 1 ps
                                            | - Print logs for my-service container running on nodes 1 and 2:
                                            |   host1$ clusterlite docker --nodes 1,2 logs my-service
                                            | - Print running processes in my-service container across all nodes:
                                            |   host1$ clusterlite docker exec -it --rm my-service ps -ef
    -------------------------------------------------------------------------------------------------------------
    expose                                 => Allow the current host to access the network of the cluster.
    hide                                   => Disallow the current host to access the network of the cluster.
    lookup                                 => Execute DNS lookup against the internal DNS service of the cluster.
      <name-to-lookup>                      | Service name or container name to lookup.
    -------------------------------------------------------------------------------------------------------------
```

notes:
sbt "universal:packageBin"
publish.sh
publish.sh --no-push
vagrant up


docker run -it --rm clusterlite/system:0.1.0 cat /clusterlite > /usr/bin/clusterlite