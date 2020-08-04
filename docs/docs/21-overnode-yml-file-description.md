---
id: overnode-yml-file-description
title: overnode.yml file description
sidebar_label: overnode.yml file
---

The file should have the following format:

```yml
id: <project-id>
version: <compose-file-version>

# zero, one or many stack sections
<stack-name>:
    # zero, one or many references to compose files
    <compose-file-reference.yml>: <placement-rule>
```

For example:

```yml
id: echo-example
version: 3.7

echo:
    echo/service.yml: *
```

## Mandatory fields

* `id` property is an *unique within a cluster* identifier of a project. Overnode can manage multiple projects in the same cluster and the `id` field value allows to identify a project.

* `version` defines Docker Compose file format version, which will be used by a project. All Docker Compose files, which are referenced by the [overnode.yml](overnode-yml-file-description) file, are required to have the same version value. Unfortunately, this *limitation* can not be easily removed as it is in the core of the Docker Compose, which is used by the Overnode.

## Stacks

* `<stack-name>` is a name of a stack. It can be any combination of letters, digits, underscore and dash symbols.

* `<compose-file-reference.yml>` is a relative path to a [configuration for Docker Compose](docker-compose-yml-file-description)

* `<placement-rule>` is a rule which defines what nodes are required to apply the referenced Docker Compose file. The allowed values:
    * `*` - all nodes
    * a set of comma-separated numbers and dash-separated ranges of numbers, for example: 1,3,5-9,12

## Using variables 

It is possible to use variables in this file. The variables should be defined in the [.env](dotenv-file-description) file.

For example, using `PRIMARY_NODE_ID` variable:

```yml
id: echo-example
version: 3.7

echo:
    echo/service.yml: ${PRIMARY_NODE_ID}
```

which could be defined as the following in the [.env](dotenv-file-description) file:

```bash
PRIMARY_NODE_ID=1
```
