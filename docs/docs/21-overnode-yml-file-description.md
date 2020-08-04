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
<stack-X>:
    # zero, one or many references to compose files
    <compose-file-X.Y>: <placement-rule-X.Y>
```

For example:

```yml
id: echo-example
version: 3.7

echo:
    echo/service.yml: *
```

## Mandatory fields

`id` property is an *unique within a cluster* identifier of a project. Overnode can manage multiple projects in the same cluster and the `id` field value allows to identify a project.

`version` defines Docker Compose file format version, which will be used by a project. All Docker Compose files, which are referenced by the [overnode.yml](overnode-yml-file-description) file, are required to have the same version value. Unfortunately, this *limitation* can not be easily removed as it is in the core of the Docker Compose, which is used by the Overnode.

## Stacks



## Placement rules

## Using variables 

