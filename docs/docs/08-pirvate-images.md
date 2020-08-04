---
id: private-images
title: Private Container Images
sidebar_label: Private Container Images
---

The Overnode tool can pull images from private Docker Hub repositories, which require user authentication. This can be done by the [login](cli-reference/login) command:

```bash
> sudo overnode login --username user
```

A password will be prompted. Alternatively, it can be supplied via stdin or an argument.

It is also possible to define custom repository server address.

In order to remove all authorizations for private repositories, use the [logout](cli-reference/logout) command:

```bash
> sudo overnode logout
```


