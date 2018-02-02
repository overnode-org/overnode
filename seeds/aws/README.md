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
- Run `export EC2_IP=$(terraform show | grep "public_ip =" | head -1 | awk '{print $3}')` to save public IP address of the first EC2 instance.
- Run `ssh -i sshkey.pem ubuntu@${EC2_IP}` to open secure shell for remote operations
- Run `sudo clusterlite nodes` - to check status of nodes
- Run `sudo clusterlite help` - for more help on operations

### Sample Configuration
File [clusterlite.yaml](./clusterlite.yaml) defines settings for sample Cassandra cluster.
When nodes are up and running, you may check that all cassandra nodes connected and formed the cluster.
Sample configuration opens client ports for Cassandra, so it can be accessed from a host machine via CQL too.

```
vagrant@m1:~$ sudo docker exec -it cassandra /opt/cassandra/bin/nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens       Owns (effective)  Host ID                               Rack
UN  10.32.4.1  104.59 KiB  32           66.1%             26fca3ba-2451-4ee4-8050-be48cdf57c8a  rack1
UN  10.32.4.2  95.09 KiB  32           67.8%             b5521f27-e613-4abb-8b3a-2fbfbb9ffdcc  rack1
UN  10.32.4.3  95.09 KiB  32           66.2%             08593a3a-18a9-4854-9cde-11dd1a4cbc59  rack1
```

Note that cassandra recognized the same IP addresses as assigned by the clusterlite:
```
vagrant@m1:~$ sudo clusterlite lookup cassandra
10.32.4.3
10.32.4.2
10.32.4.1
```

### Next steps
Modify the [clusterlite.yaml](./clusterlite.yaml) file to launch your services. You may browse for and try [other sample configurations](../../examples) to get started.
