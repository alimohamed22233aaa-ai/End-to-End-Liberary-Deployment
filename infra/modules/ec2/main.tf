resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "vpc_task"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr[count.index]
  availability_zone = "us-east-1a"

  tags = {
    Name = "publicsubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "bastion" {
  name        = "${var.sg-name}-bastion"
  vpc_id      = aws_vpc.main.id
  description = "security group of bastion server"

  ingress {
    description = "SSH from my IP and runner IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat(var.my_ip, var.runner_ip)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "server" {
  name        = var.sg-name
  vpc_id      = aws_vpc.main.id
  description = "security group of kubernetes nodes"

  ingress {
    description = "SSH from bastion host"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Kubernetes API server from nodes"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "port of app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    self        = true
  }
  ingress {
    description = "port of argocd"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }
  ingress {
    description = "Kubernetes API server from my IP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.my_ip
  }

  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }
    ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "depi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = "ali-mohamed"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  tags = {
    Name = "bastion-server"
  }
}

locals {
  nodes = [
    { name = "master-node",   subnet_index = 0 },
    { name = "worker-node-1", subnet_index = 0 },
    { name = "worker-node-2", subnet_index = 1 },
  ]
}

resource "aws_instance" "nodes" {
  count                       = 3
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public[local.nodes[count.index].subnet_index].id
  key_name                    = "ali-mohamed"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.server.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = local.nodes[count.index].name
  }
}
