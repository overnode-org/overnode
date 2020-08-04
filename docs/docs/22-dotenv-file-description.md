---
id: dotenv-file-description
title: .env file description
sidebar_label: .env file
---

This file defines a set of variables which can be used in the [overnode.yml](overnode-yml-file-description) and [referenced Docker Compose files](docker-compose-yml-file-description). The format of the file is the following:

```bash
# This is a comment

VARIABLE_NAME_1=VARIABLE_VALUE_1
# ...
VARIABLE_NAME_N=VARIABLE_VALUE_N
```

where variables names and values can be any.