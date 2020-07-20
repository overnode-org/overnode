---
id: help
title: overnode help
sidebar_label: help
---


Print this help information.
```md
> overnode [--debug] [--no-color] <action> [OPTION] ...

  Actions:   Description:
  ----------------------------------------------------------------------------
  install    Install overnode and the required dependencies.
  upgrade    Download and install newer version of overnode and dependencies.
  ----------------------------------------------------------------------------
  launch     Launch the node and / or join a cluster.
  reset      Leave a cluster and destroy the node.
  prime      Waits until the node is ready to allocate IP addresses.
  resume     Restart previously launched node if it is not running.
  ----------------------------------------------------------------------------
  connect    Add an additional target peer node to connect to.
  forget     Remove existing target peer node.
  ----------------------------------------------------------------------------
  expose     Establish connectivity between the host and the cluster.
  hide       Destroy connectivity between the host and the cluster.
  env        Print remote node connection string for docker client.
  ----------------------------------------------------------------------------
  dns-lookup Lookup DNS entries of a cluster.
  dns-add    Add extra DNS entries.
  dns-remove Remove extra DNS entries.
  ----------------------------------------------------------------------------
  login      Provide credentials to pull images from private repositories.
  logout     Remove credentials to pull images from private repositories.
  ----------------------------------------------------------------------------
  init       Download configs for services from peer nodes or external repos.
  up         Build, (re)create, and start containers for services.
  down       Stop and remove containers, networks, volumes, and images.
  ----------------------------------------------------------------------------
  start      Start existing containers of services.
  stop       Stop running containers without removing them. 
  restart    Restart all stopped and running services.
  pause      Pause running containers of services.
  unpause    Unpause paused containers of services.
  kill       Force running containers to stop by sending a signal.
  rm         Remove stopped containers of services.
  pull       Pull images associated with services.
  push       Push images for services to their respective repositories.
  ----------------------------------------------------------------------------
  ps         List containers and states of services.
  logs       Display log output from services.
  top        Display the running processes for containers of services.
  events     Stream events for containers of services in the cluster.
  config     Validate and view the configuration for services.
  status     View the state of the node, connections, dns, ipam, endpoints.
  inspect    View and inspect the state of the node in full details.
  ----------------------------------------------------------------------------
  help       Print this help information.
  version    Print version information.
  ----------------------------------------------------------------------------
```
