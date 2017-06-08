# WebIntrinsics Cluster Formation Build Scripts

[License for WebIntrinsics Cluster Formation Build Scripts](https://github.com/webintrinsics/cluster-formation/blob/master/LICENSE)

A collection of scripts
- to build docker container images for WebIntrinsics Cluster Formation
- to pull existing images from the hub
- to push built containers to the hub
- to save images of containers locally

## Configure the build tasks

Edit [tasks.sh](./tasks.sh) file.

### Define new images

Create subfolder with image name and `Dockerfile` inside. Take existing definisions as an example.

#### Notes about environment variables

`clusterlite/base` image includes the `/run.sh` script which exports the following environment variables:

  - `DEVELOPMENT_MODE` - development mode toogle
  - `SERVICE_NAME` - DNS of a service where a running container belongs to
  - `MACHINE_IP` - public host's IP interface
  - `PRIVATE_IP` - private host's IP interface (typically internal AWS IP address, if deployed on AWS)
  - `CONTAINER_IP` - internal IP address for VPN for a cluster
  - `PEER_IPS` - list of containers' IPs separated by space of all instances of the same service running inside a cluster
  - `PEER_IPS_BY_COMMA` - same separated by comma

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

When build is finished, images are available in ../lib directory.

## Run the build (building in localhost)

### Prerequsites

- Ubuntu 16.04 or CentOs 7.1 machine with
valid hostname, IP interface, DNS, proxy, apt-get/yum configuration
- Internet connection

### Actions

- run `sudo ./run.sh` - to install docker (if not installed) and complete the build tasks

When build is finished, images are available in ../lib directory.
