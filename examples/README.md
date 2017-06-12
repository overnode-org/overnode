# WebIntrinsics Cluster Formation Build Scripts

[License for WebIntrinsics Clusterlite Build Scripts](https://github.com/webintrinsics/clusterlite/blob/master/LICENSE)

A collection of scripts
- to build docker container images
- to pull existing images from the hub
- to push built containers to the hub
- to save images of containers locally

## Configure the build tasks

Edit [tasks.sh](./tasks.sh) file if necessary.

### Define new images

Create subfolder with image name and `Dockerfile` inside. Take existing definisions as an example.

## Run the build (building in virtual machine)

### Prerequsites

- [VirtualBox 5.1.14](https://www.virtualbox.org/wiki/Downloads). Note: later version may work but has not been tried.
    - [windows only] C:\Program Files\Oracle\VirtualBox\drivers\network\*\*.inf files -> Right click -> Install
- [Vagrantup 1.9.2](https://www.vagrantup.com/downloads.html). Note: later version may work but has not been tried.
- ssh in PATH (adding ssh coming with git is fine)
- Valid configuration for `http_proxy`, `https_proxy` and `no_proxy` environment variables if behind proxy
- Internet connection

### Actions

- run `vagrant up --provision` to create virtual machine environment and complete the build tasks

When build is finished, images are available in root directory.

## Run the build (building in localhost)

### Prerequsites

- Ubuntu 16.04 or CentOs 7.1 machine with
valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
- Internet connection

### Actions

- run `sudo ./run.sh` - to install docker (if not installed) and complete the build tasks

When build is finished, images are available in root directory.
