# Cade Project Seed

## Single Node Cluster over localhost

This project seed demonstrates how cade managed cluster of Docker containers can be launched over a physical machine.

### Prerequisites

- [Docker Engine](https://www.docker.com/).
You may install via `wget -q --no-cache -O - https://get.docker.com | sudo sh`
- Valid configuration for `http_proxy`, `https_proxy` and `no_proxy` environment variables if behind proxy
- Internet connection

### Installation Steps

- Run [`sudo ./install.sh`](./install.sh) in the current directory and wait the installation completes.
This 3 lines script downloads cade and launches 1 node.

### Operation Steps

- Run `sudo cade nodes` - to check status of nodes
- Run `sudo cade help` - for more help on operations

### Sample Configuration
File [cade.yaml](./cade.yaml) defines settings for sample Cassandra cluster.
When the node is up and running, you may check that single cassandra node is running.
Sample configuration opens client ports for Cassandra, so it can be accessed from localhost via CQL too.

```
user@localhost:~$ sudo docker exec -it cassandra /opt/cassandra/bin/nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens       Owns (effective)  Host ID                               Rack
UN  10.32.4.1  104.59 KiB  32           100%             26fca3ba-2451-4ee4-8050-be48cdf57c8a  rack1
```

Note that cassandra recognized the same IP address as assigned by the cade:
```
user@lolcahost:~$ sudo cade lookup cassandra
10.32.4.1
```

### Next steps
Modify the [cade.yaml](./cade.yaml) file to launch your services. You may browse for and try [other sample configurations](../../examples) to get started.
