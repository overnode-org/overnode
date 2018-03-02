# Examples of cade configurations

A collection of scripts
- to build docker container images
- to pull existing images from the hub
- to push built containers to the hub
- to save images of containers locally

## Configure the build tasks

Edit [tasks.sh](./tasks.sh) file if necessary. Available tasks are:
- build_image
- save_image
- pull_image
- push_image

### Define new images

Create subfolder with image name and `Dockerfile` and `files/version.txt` files inside. Check existing definitions, for example [cassandra](./cassandra) or [telegraf](./telegraf).

## Run the build (building in localhost)

### Prerequsites

- Ubuntu 16.04 or CentOs 7.1 machine with
valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
- Internet connection

### Actions

- run `sudo ./run.sh` - to install docker (if not installed) and complete the build tasks

