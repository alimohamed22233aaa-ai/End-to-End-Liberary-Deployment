terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


provider "aws" {
  region  = "us-east-1"
    # profile = "depi_project"
}
module "task1" {
    source = "../modules/ec2"
    vpc_cidr    = var.vpc_cidr
    subnet_cidr = var.subnet_cidr
    sg-name     = var.sg-name
    my_ip       = var.my_ip
}

resource "local_file" "inventory" {
  filename = "../../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.txt", {
    bastion_ip = module.task1.bastion_public_ip
    master_ip  = module.task1.master_private_ip
    worker1_ip = module.task1.worker1_private_ip
    worker2_ip = module.task1.worker2_private_ip
  })
}
