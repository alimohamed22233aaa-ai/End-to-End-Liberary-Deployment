output "master_private_ip" {
  value = aws_instance.nodes[0].private_ip
}

output "worker1_private_ip" {
  value = aws_instance.nodes[1].private_ip
}

output "worker2_private_ip" {
  value = aws_instance.nodes[2].private_ip
}
output "bastion_public_ip" {
  value = aws_instance.depi.public_ip
}
