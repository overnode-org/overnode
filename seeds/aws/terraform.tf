variable "aws_access_key" {
  type = "string"
}

variable "aws_secret_key" {
  type = "string"
}

variable "aws_region" {
  type    = "string"
  default = "ap-southeast-2"
}

variable "aws_region_zone_1" {
  type    = "string"
  default = "ap-southeast-2a"
}

variable "aws_region_zone_2" {
  type    = "string"
  default = "ap-southeast-2b"
}

variable "aws_region_zone_3" {
  type    = "string"
  default = "ap-southeast-2c"
}

variable "aws_cidr" {
  type    = "string"
  default = "172.31.0.0/16"
}

variable "aws_ami_image" {
  type    = "string"
  default = "ami-a80114cb"
}

variable "aws_instance_type" {
  type    = "string"
  default = "m3.medium"
}

variable "aws_service_name" {
  type    = "string"
  default = "cluterlite.demo"
}

variable "aws_key_pair_public" {
  type = "string"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

# Security group for nodes
resource "aws_security_group" "node-security-group" {
  name        = "${replace(var.aws_service_name, ".", "-")}"
  description = "Allow service specific inbound and weavenet intra-node traffic"

  # weavenet intra-node traffic (assuming default AWS subnet)
  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "udp"
    cidr_blocks = ["${var.aws_cidr}"]
  }

  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_cidr}"]
  }

  ingress {
    from_port   = 6784
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = ["${var.aws_cidr}"]
  }

  # Service specific traffic:
  # should reflect open ports from the cade.yaml file,
  # if you would like to expose the service publicly
  ingress {
    from_port        = 9042          # Cassandra clients port in the example cade.yaml
    to_port          = 9042          # Cassandra clients port in the example cade.yaml
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # SSH traffic to manage hosts
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags {
    "Service" = "${var.aws_service_name}"
    "Name"    = "${var.aws_service_name}"
  }
}

# Key pair for nodes
resource "aws_key_pair" "node-key-pair" {
  key_name = "${replace(var.aws_service_name, ".", "-")}"

  # note: corresponding private key is in the sshkey.pem file
  public_key = "${var.aws_key_pair_public}"
}

# EC2 Instances (nodes)
resource "aws_instance" "node-1b" {
  ami               = "${var.aws_ami_image}"
  instance_type     = "${var.aws_instance_type}"
  key_name          = "${aws_key_pair.node-key-pair.key_name}"
  availability_zone = "${var.aws_region_zone_1}"
  security_groups   = ["${aws_security_group.node-security-group.name}"]

  tags {
    "Service" = "${var.aws_service_name}"
    "Name"    = "${var.aws_service_name}-1"
  }
}

resource "aws_instance" "node-2b" {
  ami               = "${var.aws_ami_image}"
  instance_type     = "${var.aws_instance_type}"
  key_name          = "${aws_key_pair.node-key-pair.key_name}"
  availability_zone = "${var.aws_region_zone_2}"
  security_groups   = ["${aws_security_group.node-security-group.name}"]

  tags {
    "Service" = "${var.aws_service_name}"
    "Name"    = "${var.aws_service_name}-2"
  }
}

resource "aws_instance" "node-3b" {
  ami               = "${var.aws_ami_image}"
  instance_type     = "${var.aws_instance_type}"
  key_name          = "${aws_key_pair.node-key-pair.key_name}"
  availability_zone = "${var.aws_region_zone_3}"
  security_groups   = ["${aws_security_group.node-security-group.name}"]

  tags {
    "Service" = "${var.aws_service_name}"
    "Name"    = "${var.aws_service_name}-3"
  }
}

# install cade nodes on every instance
resource "null_resource" "node-1b-init-cluster" {
  triggers {
    instance = "${aws_instance.node-1b.id}"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${path.module}/sshkey.pem")}"
    host        = "${aws_instance.node-1b.public_ip}"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/master/utils/install-docker-17.05.0-ubuntu-16.04.sh | sudo sh",
      "sleep 10",
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/0.7.1/install.sh | sudo sh",
      "sudo cade install --token sdfsafdsfsadfsadfsdf97987sdf987sadf7asd8f7s98f7sd89f --seeds ${aws_instance.node-1b.private_ip},${aws_instance.node-2b.private_ip},${aws_instance.node-3b.private_ip}  --public-address ${aws_instance.node-1b.public_ip} --placement default || echo ___INSTALL_EXIT_CODE_IGNORED___",
    ]
  }
}

resource "null_resource" "node-2b-init-cluster" {
  triggers {
    instance = "${aws_instance.node-2b.id}"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${path.module}/sshkey.pem")}"
    host        = "${aws_instance.node-2b.public_ip}"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/master/utils/install-docker-17.05.0-ubuntu-16.04.sh | sudo sh",
      "sleep 10",
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/0.7.1/install.sh | sudo sh",
      "sudo cade install --token sdfsafdsfsadfsadfsdf97987sdf987sadf7asd8f7s98f7sd89f --seeds ${aws_instance.node-1b.private_ip},${aws_instance.node-2b.private_ip},${aws_instance.node-3b.private_ip}  --public-address ${aws_instance.node-2b.public_ip} --placement default || echo ___INSTALL_EXIT_CODE_IGNORED___",
    ]
  }
}

resource "null_resource" "node-3b-init-cluster" {
  triggers {
    instance = "${aws_instance.node-3b.id}"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${path.module}/sshkey.pem")}"
    host        = "${aws_instance.node-3b.public_ip}"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/master/utils/install-docker-17.05.0-ubuntu-16.04.sh | sudo sh",
      "sleep 10",
      "sudo wget -q --no-cache -O - https://raw.githubusercontent.com/cadeworks/cade/0.7.1/install.sh | sudo sh",
      "sudo cade install --token sdfsafdsfsadfsadfsdf97987sdf987sadf7asd8f7s98f7sd89f --seeds ${aws_instance.node-1b.private_ip},${aws_instance.node-2b.private_ip},${aws_instance.node-3b.private_ip}  --public-address ${aws_instance.node-3b.public_ip} --placement default || echo ___INSTALL_EXIT_CODE_IGNORED___",
    ]
  }
}

# apply latest containers placements
resource "null_resource" "cade-yaml-apply" {
  triggers {
    cade_yaml_file = "${sha1(file("${path.module}/cade.yaml"))}"
  }

  depends_on = [
    "null_resource.node-1b-init-cluster",
    "null_resource.node-2b-init-cluster",
    "null_resource.node-3b-init-cluster",
  ]

  connection {
    user        = "ubuntu"
    private_key = "${file("${path.module}/sshkey.pem")}"
    host        = "${aws_instance.node-3b.public_ip}"
    agent       = false
  }

  provisioner "file" {
    source      = "cade.yaml"
    destination = "/tmp/cade.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cade apply --config /tmp/cade.yaml",
    ]
  }
}
