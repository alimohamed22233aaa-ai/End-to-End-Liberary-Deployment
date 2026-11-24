terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "my-depi-terraform-tfstate-bucket"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}


provider "aws" {
  region  = "us-east-1"
   
}
module "task1" {
    source = "../modules/ec2"
    vpc_cidr    = var.vpc_cidr
    subnet_cidr = var.subnet_cidr
    sg-name     = var.sg-name
    my_ip       = var.my_ip
    runner_ip = var.runner_ip   
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

