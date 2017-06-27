# clusterlite
Simple but powerful alternative to Kubernetes and Docker Swarm

TBD

## Help

```
> clusterlite [--debug] <action> [OPTIONS]

  Actions / Options:
  ----------------------------------------------------------------------------
  help      Print this help information.
  version   Print version information.
  ----------------------------------------------------------------------------
  install   Install clusterlite node on the current host and join the cluster.
    --token <cluster-wide-token>
            Cluster-wide secret key should be the same for all joining hosts.
    --seeds <host1,host2,...>
            Seed nodes store cluster-wide configuration and coordinate various
            cluster management tasks, like assignment of IP addresses.
            Seeds should be private IP addresses or valid DNS host names.
            3-5 seeds are recommended for high-availability and reliability.
            7 is the maximum to keep efficient quorum-based coordination.
            When a host joins as a seed node, it should be listed in the seeds
            parameter value and *order* of seeds should be the same on all
            joining seeds! Seed nodes can be installed in any order or
            in parallel: the second node joins when the first node is ready,
            the third joins when two other seeds form the alive quorum.
            When host joins as a regular (non seed) node, seeds parameter can
            be any subset of existing seeds listed in any order.
            Regular nodes can be launched in parallel and
            even before the seed nodes, they will join eventually.
    [--volume /var/lib/clusterlite]
            Directory where stateful services will persist data. Each service
            will get it's own sub-directory within the defined volume.
    [--public-address <ip-address>]
            Public IP address of the host, if it exists and requires exposure.
    [--placement default]
            Role allocation for a node. A node schedules services according to
            the matching placement defined in the configuration file,
            which is set via 'apply' action.
    Example: initiate the cluster with the first seed node:
      host1> clusterlite install --token abcdef0123456789 --seeds host1
    Example: add 2 other hosts as seed nodes:
      host2> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3
      host3> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3
    Example: add 1 more host as regular node:
      host4> clusterlite install --token abcdef0123456789 --seeds host1,host2,host3
  uninstall Destroy containers scheduled on the current host,
            remove data persisted on the current host and leave the cluster.
  ----------------------------------------------------------------------------
  info      Show cluster-wide information, like IDs of nodes.
  ----------------------------------------------------------------------------
  login     Provide credentials to download images from private repositories.
    --username <username>
            Docker registry username.
    --password <password>
            Docker registry password.
    [--registry registry.hub.docker.com]
            Address of docker registry to login to. If you have got multiple
            different registries, execute 'login' action multiple times.
            Credentials can be also different for different registries.
  logout    Removes credentials for a registry.
    [--registry registry.hub.docker.com]
            Address of docker registry to logout from. If you need to logout
            from multiple different registries, execute it multiple times
            specifying different registries each time.
  ----------------------------------------------------------------------------
  plan      Inspect the current state of the cluster against
            the current or the specified configuration and show
            what changes the 'apply' action will provision once invoked
            with the same configuration and the same state of the cluster.
            The action is applied to all nodes of the cluster.
    [--config /path/to/yaml/file]
            Cluster-wide configuration of services and placement rules.
            If it is not specified, the latest applied configuration is used.
  apply     Inspect the current state of the cluster against
            the current or the specified configuration and apply
            the changes required to bring the state of the cluster
            to the state specified in the configuration. This action is
            cluster-wide operation, i.e. every node of the cluster will
            download necessary docker images and schedule running services.
    [--config /path/to/yaml/file]
            Cluster-wide configuration of services and placement rules.
            If it is not specified, the latest applied configuration is used.
  show      Show the current state of the cluster and details
            about downloaded images and created containers and services.
            The action is applied to all nodes of the cluster.
  destroy   Terminate all running containers and services.
            The action is applied to all nodes of the cluster.
  ----------------------------------------------------------------------------
  docker    Run docker command on one, multiple or all nodes of the cluster.
    [--nodes 1,2,..]
            Comma separated list of IDs of nodes where to run the command.
            If it is not specified, the action is applied to all nodes.
    <docker-command> [docker-options]
            Valid docker command and options. See docker help for details.
    Example: list running containers on node #1:
      hostX> clusterlite docker ps --nodes 1
    Example: print logs for my-service container running on nodes 1 and 2:
      hostX> clusterlite docker logs my-service --nodes 1,2
    Example: print running processes in my-service container for all nodes:
      hostX> clusterlite docker exec -it --rm my-service ps -ef
  ----------------------------------------------------------------------------
  expose    Allow the current host to access the network of the cluster.
  hide      Disallow the current host to access the network of the cluster.
  lookup    Execute DNS lookup against the internal DNS of the cluster.
            The action is applied to all nodes of the cluster.
    <service-name>
            Service name or container name to lookup.
  ----------------------------------------------------------------------------
```

notes:
sbt "universal:packageBin"
publish.sh
publish.sh --no-push
vagrant up


docker run -it --rm clusterlite/system:0.1.0 cat /clusterlite > /usr/bin/clusterlite