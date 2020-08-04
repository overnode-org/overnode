---
id: managing-containers-workflow
title: Managing Containers - Workflow
sidebar_label: Workflow Essentials
---

## Initiating a project

Overnode commands, like [up](cli-reference/up), [start](cli-reference/start), [stop](cli-reference/stop), and other commands, manipulate the state of containers. Containers are defined in a project configuration files.

Project configuration consists of the main [overnode.yml](overnode-yml-file-description) file and a number of [Docker Compose configuration files](docker-compose-yml-file-description), which are referenced in the [overnode.yml](overnode-yml-file-description) file.

You can manually create the minimal required empty configuration or use the [init](cli-reference/init) command in some empty working directory:

```bash
> sudo overnode init 
```

This will create the default [overnode.yml](overnode-yml-file-description) file, [.env](dotenv-file-description) and [.overnodeignore](overnodeignore-file-description) files. 

The content of the [overnode.yml](overnode-yml-file-description) file will be similar to the following:

```yml
# Unique project id. Do not delete this field.
# It is OK to set it to some recognizable name initially.
# Once defined and set, do not edit.
id: my-overnode-project

# Docker compose file version to use across
version: 3.7

# Hint: run the following command to add sample service to the configuration
# > overnode init https://github.com/overnode-org/overnode#examples/echo
```

`id` and `version` are mandatory top level properties and explained in more details in the [Configuration Reference](overnode-yml-file-description).

This default configuration does not define any containers, but enables related container management overnode commands to work, for example:

```bash
> sudo overnode config --services
```

## Launching a service

Let's add an application. We will run [echo](https://hub.docker.com/r/ealen/echo-server) server as our *Hello World* application.

We need to create Docker Compose file, which defines the service. Check out the [referenced Compose files documentation](docker-compose-yml-file-description) for the details about the fields and options. As a minimal required configuration for the Echo service, we will use the following:

```yml
version: "3.7"
services:
    echo:
        # Use bridge mode to attach the container to the cluster network
        network_mode: bridge
        image: ealen/echo-server
        restart: unless-stopped
        ports:
            - 3000:80
```
:::important
Notice the `network_mode` is set to `bridge`. This is required for attaching the container to the cluster network managed by weavenet.

And the `restart` is set to `unless-stopped` to make it automatically restartable on a crash or host restart. This will make it running like a service but not as one-off process.
:::

We save it to `echo/service.yml` file and reference it in the [overnode.yml](overnode-yml-file-description) file by adding the following section:

```yml
echo:
    echo.yml: *
```

Where:

* `echo` is a stack name, we assigned
* `echo/service.yml` is a path to the Docker Compose file, we previously created
* `*` is a [placement rule](overnode-yml-file-description#placement-rules), which defines the referred file should be applied to every Overnode node

You can assign any names for stacks and files as long as they contain the allowed set of characters. Docker Compose files should be placed in the same directory or it's sub-directories as the overnode.yml file.

The same project can have many stacks. A stack can refer to many different Docker Compose files. Each referenced file can have different [placement rule](overnode-yml-file-description#placement-rules).

Now we can bring the service up:

```bash
> sudo overnode up
```

And see it responding on HTTP requests:

```bash
> curl localhost:3000
{"host":{"hostname":"localhost","ip":"::ffff:172.17.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{"0":"/"},"query":{},"cookies":{},"body":{},"headers":{"host":"localhost:3000","user-agent":"curl/7.58.0","accept":"*/*"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"echo.weave.local","NODE_VERSION":"12.18.3","YARN_VERSION":"1.22.4","HOME":"/root"}}
```

## Sharing configurations

You can also see the hint in the generated [overnode.yml](overnode-yml-file-description) file about adding an example service by running the [init](cli-reference/init) command with arguments. This feature allows to reuse pre-configured, published and shared stacks without writing or copying configuration files manually.

So, you can add the same pre-configured [echo](https://hub.docker.com/r/ealen/echo-server) server by running:

```bash
> sudo overnode init https://github.com/overnode-org/overnode#examples/echo
```

Overnode can also pull configurations from private repositories. You will need to enter username and password to authenticate the client.

## Restoring configurations

If your cluster already runs a project, you can restore it's configuration files to any directory by running the [init](cli-reference/init) command with the restore argument. It is necessary to know the project unique identifier, if the default detected project ID is not right. For example:

```bash
> sudo overnode --restore --project my-overnode-project
```

If you also would like to version control your configurations, you can store it in a local and/or remote git repository. 

## Inspecting services

In order to list containers and services status, use [ps](cli-reference/ps) command:

```bash
> sudo overnode ps
```

Other useful troubleshooting commands are [logs](cli-reference/logs), [top](cli-reference/top), [events](cli-reference/events) and [config](cli-reference/config).

## Updating a service

In order to apply any changes, update any of the configuration files and run [up](cli-reference/up) command again.

## Destroying a service

If you do not need the service anymore, remove the references to the Docker Compose files from the [overnode.yml](overnode-yml-file-description) file and run [up](cli-reference/up) command again with `--remove-orphans` flag:

```bash
> sudo overnode up --remove-orphans
```

## Destroying a project

If you do not need anymore all containers, volumes and images created by a project, run [down](cli-reference/down) command to destroy containers and, optionally, volumes and images:

```bash
> sudo overnode down --remove-orphans --remove-volumes --remove-images
```

## Related commands

Other commands related to containers state management are:
* [start](cli-reference/start) / [restart](cli-reference/restart) / [stop](cli-reference/stop),
* [pause](cli-reference/pause) / [unpause](cli-reference/unpause),
* [kill](cli-reference/kill) / [rm](cli-reference/rm),
* [pull](cli-reference/pull) / [push](cli-reference/push)