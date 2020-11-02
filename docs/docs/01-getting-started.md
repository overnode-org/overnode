---
id: getting-started
title: Introduction
sidebar_label: Introduction
---

## Welcome

Thanks for expressing interest in the tool!

### Overview

Overnode is a multi-host container orchestration tool with a focus on **simplicity** and **predictability**.

**Simple** means:

* Learning the tool is a quick process. Typically, it takes about 15 minutes to go through the tutorial.
* Deployment configurations for applications are easy to understand and 100% compatible with standalone docker-compose configuration files.
* CLI commands are intuitive and familiar.
* Easy reuse of pre-configured stacks, published publicly or privately. Overnode provides pre-configured stacks for monitoring and alerting by Prometheus and friends, central logging by Loki and Grafana, and ultimate visibility and application understanding via Weave Scope's interactive dashboard.
* Operational complexity does not grow with a cluster scaling out to more and more nodes.
* Console messages are helpful in all cases, including abnormal and corner cases.
* Tools are available for enjoyable and easy troubleshooting of problems with a cluster or containers.
* The source code of the tool is a relatively short shell script, which builds on top of two other easy to use products: docker-compose and weavenet.

**Predictable** means:

* Configuration files define everything required for a deployment.
* (Re-)deployments are repeatable / reproducible. Operations / actions are automatically inferred from the current state of a cluster and the required state in the configuration.
* Changes to containers or cluster can be triggered only by explicit overnode (or docker) commands.
* Upgrades in production are safe with distributed rollover upgrade option.
* You have got full control of placement, scheduling and all parameters of docker containers.

We hope the tool becomes useful for you and you enjoy using it.

### Comparison with alternatives

There are the following well-known tools serving in the domain of *container orchestration*:

* Kubernetes - most advanced, most feature-rich, incredibly agile evolution of the project. However, it comes with a cost of complexity: both development and maintenance. It demands more compute resources, and relies on more experienced operators / administrators. It needs more of your time to follow the rapid changes in the project, as such, it can be considered as *overkill* for many applications / deployments.
* Docker Swarm - far easier than Kubernetes. It is similar to Overnode, from the simplicity point of view. Still, it is not as simple, and certainly, not as predictable as Overnode. In our humble biased opinion, it also disables some features of standalone Docker, making it harder to deploy some applications. In addition, it does not have some of the features of Overnode has, for example automated deployment of configuration files.
* Nomad Project - another thing to look into, sitting somewhere between Kubernetes and Docker Swarm from the complexity point of view.


### Learning the tool

In this **Getting Started** section we will go through the steps in the format of a semi-tutorial. It will take about 15 minutes to read it and maybe a bit longer, if you decide to follow the tutorial and try the commands yourself. You will need only one host to follow the tutorial. However, if you have got multiple hosts to form a cluster, you can use multiple-hosts. It can make it a more interesting exercise.
