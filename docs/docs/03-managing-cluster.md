---
id: managing-cluster
title: Managing Cluster Nodes
sidebar_label: Managing Cluster Nodes
---

## Concepts

Overnode cluster is a **set of nodes**, managed by the overnode. A node runs on a host: a virtual machine, a cloud instance or an OS with bare metal hardware. One host can run only one node.

Every node has got a set of configurable **target nodes**. A node proactively initiates a connection with the target nodes on start up and after a connection is lost. All other (non-target) nodes are discovered eventually via gossips and also inter-connected with each other. Connections are initiated to ports 6783 and 6784 via TCP and UDP protocols, so it should be allowed on a host / networking / firewall level. Selection of target nodes for each node is a decision you will have to make depending on an application, networking constraints, etc. As a safe default option, aim for each node to have every other node added as a target node.

Every node is assigned explicitly a **unique identifier (ID)**. There are no master or worker nodes. All nodes are equal (but can run different jobs, of course). However only a node with an ID 1, 2, 3 or 4 can assign IP addresses to containers. Nodes can start in any order and can function in complete isolation (network partitioning) from other nodes. A node can launch a container even in case of network partitioning, provided it can assign an IP address, i.e. it has got an ID from 1 to 4 or it is connected to a node with an ID in this range.

Every node of a cluster shares the same **password token**. A node can be accepted by a target node only if it is configured with the same token. The token is defined once and never changes. The traffic between the nodes is encrypted and the token is used as an encryption / decryption key.

## Launching and connecting nodes

To launch a node, use [launch](cli-reference/launch) command, for example:

```bash
host1 > sudo overnode launch --id 1 --token my-cluster-password
```

To add target nodes for a node, use [connect](cli-reference/connect) command (target nodes do not have to be reachable or even exist to be added as target nodes):

```bash
host1 > sudo overnode connect host2
```

As a shortcut, you can provide target nodes during launch:

```bash
host1 > sudo overnode launch --id 1 --token my-cluster-password host2
```

A node can be a target for itself, it just skips connecting to itself in this case:

```bash
host1 > sudo overnode launch --id 1 --token my-cluster-password host1 host2
```

#### Example 1: 4x nodes cluster formed initially, other nodes added later

Initially:

```bash
host1 > sudo overnode launch --id 1 --token my-cluster-password host1 host2 host3 host4
host2 > sudo overnode launch --id 2 --token my-cluster-password host1 host2 host3 host4
host3 > sudo overnode launch --id 3 --token my-cluster-password host1 host2 host3 host4
host4 > sudo overnode launch --id 4 --token my-cluster-password host1 host2 host3 host4
```

Later:

```
# add as many more nodes as needed
host5 > sudo overnode launch --id 5 --token my-cluster-password host1 host2 host3 host4
```

First 4 nodes are defined as target nodes for all nodes.

#### Example 2: 1x node cluster formed initially, other nodes added and targeted later

Initially:

```bash
host1 > sudo overnode launch --id 1 --token my-cluster-password host1
```

Later:

```bash
host1 > sudo overnode connect host2
host2 > sudo overnode launch --id 2 --token my-cluster-password host1 host2
```

Later:

```bash
host1 > sudo overnode connect host3
host2 > sudo overnode connect host3
host3 > sudo overnode launch --id 3 --token my-cluster-password host1 host2 host3
```

And so on.

## Inspecting cluster nodes

The following set of commands might be useful for getting more visibility into the current status of a cluster:

### Configured target nodes

```bash
> sudo overnode status --targets
```

### Peers status

```bash
> sudo overnode status --peers
```

### Connections status

```bash
> sudo overnode status --connections
```

### IP addresses allocation status

```bash
> sudo overnode status --ipam
```

## Stopping and removing nodes

To stop and destroy a node, use [reset](cli-reference/reset) command, for example:

```bash
host3 > sudo overnode reset
```

If the removed node was a target node for other nodes, tell other nodes to forget about it:

```bash
host1 > sudo overnode forget host3
host2 > sudo overnode forget host3
```

[forget](cli-reference/forget) command is the opposite to [connect](cli-reference/connect) command.

Once the node is reset, it can be launched again. And can be connected to the same cluster or different one.

## Related commands

### Resuming nodes

Normally, nodes automatically start when a host (docker engine) starts. There is no command to pause it, unless you use plain docker commands to manipulate the containers. So, it is unlikely you will need to resume a node. However, if it happens you need, there is the [resume](cli-reference/resume) command for this purpose:

```bash
> sudo overnode resume
```

### Waiting for launch *completed*

You would not normally need to wait for a node after launching a node. However, it is useful sometimes for external automation tools, which do things, like automated scaling, for a cluster.

[prime](cli-reference/prime) command blocks until a node is ready to allocate IP addresses, which means it is ready to start containers.

```bash
> sudo overnode prime
```

### Inspecting detailed status

The [inspect](cli-reference/inspect) command dumps all the details of the underlining weavenet state in JSON format:

```bash
> sudo overnode inspect
```
