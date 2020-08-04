---
id: configs-and-secrets-storage
title: Settings and Secrets Volume
sidebar_label: Settings / Secrets Volume
---

## Provisioning settings directory

Many applications require custom configurations, secrets, SSL certificates and various other settings stored in files outside of a container image. A typical approach to providing the required files for processes in a container is to mount a local directory or a file to a container. A cluster of distributed hosts does not have such a *local directory* equally available for all of the hosts unless you opt into some sort of network file system.

Overnode takes simpler approach. It uploads the content of a current working project directory to all of the nodes, when the [up](cli-reference/up) command is invoked. The [down](cli-reference/down) command reverts the action. The uploaded files and sub directories can be universally mounted to containers using [OVERNODE_ETC](docker-compose-yml-file-description#overnode_etc) environment variable.

For example, let's create a file for the echo service, which we [played with before](managing-containers-workflow#launching-a-service):

```bash
> echo "Hello World!" > echo/hello-world.txt
```

And now mount it to the echo server container to the `/settings` path as readonly:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        restart: unless-stopped
        image: ealen/echo-server
        ports:
            - 3000:80
        volumes:
            - ${OVERNODE_ETC}/echo:/settings:ro
```

Once the configuration is reapplied:

```bash
> sudo overnode up
```

The echo server can serve the provisioned file:

```bash
> curl localhost:3000?echo_file=/settings/hello-world.txt
Hello World!
```

## Excluding files / directories

By default, the Overnode uploads all of the files from the working project directory. You can exclude some files or directories by enumerating them in the [.overnodeignore](overnodeignore-file-description) file. The minimal recommended content for the file is the following:

```
.overnode
.overnodebundle
```

## Recreating containers on settings change

When supportive settings or secret files are updated and re-uploaded again with the [up](cli-reference/up) command, some processes within containers may detect the updates in files and take the required actions automatically. But some other may require a restart, which you can trigger with help of the [restart](cli-reference/restart) command. Alternatively, we can implement the strategy to re-create affected containers after the upload automatically.

Let's say we would like to re-create the container for the above configured `echo` service, when the `hello-world.txt` file is changed.

First of all, we instruct the Overnode to md5 hash the content of the required file or directory automatically before every upload by placing md5env file with a corresponding name and location. For example:

```bash
> ls ./echo
hello-world.txt  service.yml
> touch ./echo/hello-world.txt.md5env
```

And secondly, we instruct the underlying Docker Compose engine to use the hash value as an environment variable via the `env_file` property. The change in the environment variable value will force recreation of a container:

```yml
version: "3.7"
services:
    echo:
        network_mode: bridge
        restart: unless-stopped
        image: ealen/echo-server
        ports:
            - 3000:80
        volumes:
            - ${OVERNODE_ETC}/echo:/settings:ro
        env_file:
            - echo/hello-world.txt.md5env
```

Finally, the [up](cli-reference/up) command will always trigger re-creation for containers, which project the updated md5env file:

```bash
> sudo overnode up
```

We can also check the hash environment variable value echoed by the server:

```bash
> curl localhost:3000?echo_env_body=OVERNODE_MD5SUM___ECHO_HELLO_WORLD_TXT
"8DDD8BE4B179A529AFA5F2FFAE4B9858"
```
