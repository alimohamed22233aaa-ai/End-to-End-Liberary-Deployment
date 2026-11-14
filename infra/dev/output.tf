output "master_private_ip" {
  value = module.task1.master_private_ip
}

output "worker1_private_ip" {
  value = module.task1.worker1_private_ip
}

output "worker2_private_ip" {
  value = module.task1.worker2_private_ip
}
output "bastion_public_ip" {
  value = module.task1.bastion_public_ip
}