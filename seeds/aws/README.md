# Clusterlite Project Seed

## Distributed Cluster over set of AWS instances

This project seed demonstrates how clusterlite managed cluster of Docker containers can be launched over a set of AWS EC2 instances.
The project automates creation of AWS infrastructure:
- three EC2 instances spread across 3 availability zones
- configured with right security groups for intra-node communication
- configured with pre-generated key pair ([sshkey.pem](./sshkey,pem)) for SSH access

### Prerequisites

- [Terraform] (https://www.terraform.io/). It is used to create AWS infrastructure automatically.
- ssh in PATH (adding ssh coming with git is fine)
- Valid configuration for `http_proxy`, `https_proxy` and `no_proxy` environment variables if behind proxy
- Internet connection
- Valid AWS Access and Secret keys for CLI operations.
These keys should grant access to Full EC2 Instances operations.

### Provisioning Steps

- Set your AWS Access and Secret keys in the [terraform.tfvars](./terraform.tfvars) file.
- Optionally edit other variables (eg. if you would like to use another region for deployment).
- Run `terraform apply` - to create AWS instances and provision them into Clusterlite-managed cluster.

### Operation Steps

- Run `terraform show | grep public_ip` to list public IP addresses for all created EC2 instances.
- Run `ssh -i sshkey.pem ubuntu@<one-of-public-ip-address>` to open secure shell for remote operations
- Run `sudo clusterlite nodes` - to check status of nodes
- Run `sudo clusterlite help` - for more help on operations

### Sample Configuration
File [clusterlite.yaml](./clusterlite.yaml) defines settings for sample Cassandra cluster.
When nodes are up and running, you may check that all cassandra nodes connected and formed the cluster.
Sample configuration opens client ports for Cassandra, so it can be accessed from a host machine via CQL too.

```
ubuntu@ip-172-31-11-9:~$ sudo docker exec -it cassandra /opt/cassandra/bin/nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens       Owns (effective)  Host ID                               Rack
UN  10.32.1.1  104.57 KiB  32           48.7%             69a661f6-1a56-4e84-b723-5fd1b841f7ce  rack1
UN  10.32.1.2  178.66 KiB  32           73.1%             82fba3f2-5610-4c63-b902-d1c5f72a3ef3  rack1
UN  10.32.1.3  100.18 KiB  32           78.2%             29281f56-bdf6-4f3d-9d9f-b7f9f38fd396  rack1
```

Note that cassandra recognized the same IP addresses as assigned by the clusterlite:
```
ubuntu@ip-172-31-11-9:~$ sudo clusterlite lookup cassandra
10.32.1.1
10.32.1.3
10.32.1.2
```

### Next steps
Modify the [clusterlite.yaml](./clusterlite.yaml) file to launch your services. You may browse for and try [other sample configurations](../../examples) to get started.
