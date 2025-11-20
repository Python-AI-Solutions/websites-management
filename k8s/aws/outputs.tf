output "jump_host_instance_id" {
  description = "Managed EC2 instance identifier."
  value       = aws_instance.jump_host.id
}

output "jump_host_private_ip" {
  description = "Private IP of the jump host (bastion)."
  value       = aws_instance.jump_host.private_ip
}

output "security_group_id" {
  description = "Security group ID for the jump host."
  value       = aws_security_group.jump_host.id
}

output "jump_host_public_ip" {
  description = "Public IP assigned to the jump host (from the persistent EIP module)."
  value       = var.bastion_public_ip
}
