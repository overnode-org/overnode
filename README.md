# Clusterlite
Simple but powerful alternative to Kubernetes, DC/OS and Docker Swarm.

## Motivation
The tool was grown naturally during development and simplification
of our operations. It was inspired by:
  - **declarative configurability** of Kubernetes,
  - **simplicity** of Docker Swarm,
  - **usability** of Weave Net,
  - and **visibility / transparency** given by Terraform.

We attempted to combine these characteristics in one tool
and believe we have got something what helps us to make
our operations simple, visible and powerful enough for our needs.

## Features

  - Installation does not require external cluster coordination or storage.
  - Nodes can be launched in parallel even in condition of network partition.
  - Replicated and fault-tolerant internal storage for cluster state and configurations.
  - Declarative configuration for services, dependencies, placement rules, etc. in YAML format.
  - Ability to plan provisioning of changes to the infrastructure with much visibility
  before applying these changes.
  - Ability to execute cluster-wide operations from a single node.
  - Pulls docker images from multiple docker registries, including private registries.
  - Predictable assignment of IP addresses for "seed" containers of a distributed service,
  before these seed containers are even created.
  - Preserves IP addresses for containers when a failed node is replaced by another.
  - Differentiates private and public IP addresses for virtualized, cloud-like environments.

## Features in roadmap
  - a command to replace and repair failed node
  - reconfiguration for placement and public IP address of a node
  - add more container options into to configuration
  - complete some tear-down and clean up actions
  - add ability to inherit sections of a configuration to reduce duplication
  - add automated tests for examples
  - get rid of terraform, which is used internally, but does not provide enough value anymore

## Help

```
> clusterlite [--debug] <action> [OPTIONS]

  Actions / Options:
  ----------------------------------------------------------------------------
  help      Print this help information.
  version   Print version information.
  ----------------------------------------------------------------------------
  nodes     Show information about installed nodes.
            Nodes are instances of connected to a cluster machines.
            Run 'install'/'uninstall' actions to add/remove nodes.
  users     Show information about active credentials.
            Credentials are used to pull images from private repositories.
            Run 'login'/'logout' actions to add/change/remove credentials.
  files     Show information about uploaded files.
            Files are used to distribute configurations/secrets to services.
            Run 'upload'/'download' actions to add/remove/view files content.
  services  Show the current state of the cluster, details
            about downloaded images, created containers and services
            across all nodes of the cluster. Run 'apply'/'destroy' actions
            to change the state of the cluster.
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
  upload    Upload new file content or delete existing.
    [--source </path/to/text/file>]
            Path to a file to upload. If not specified, target parameter
            should be specified and the action will cause deletion
            of the file referred by the target parameter.
    --target <file-id>
            Reference of a file to upload to or delete. If not specified,
            source parameter should be specified and target parameter
            will be set to source file name by default.
  download   Print content of a file by it's reference.
    --target <file-id>
            Reference of a file to print. Use 'files' action to get the list
            of available files.
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

## Development notes:
TODO remove it
sbt "universal:packageBin"
publish.sh
publish.sh --no-push
vagrant up
docker run -it --rm clusterlite/system:0.1.0 cat /clusterlite > /usr/bin/clusterlite