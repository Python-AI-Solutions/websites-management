output "jump_host_instance_id" {
  description = "Managed EC2 instance identifier."
  value       = aws_instance.jump_host.id
}

output "jump_host_public_ip" {
  description = "Elastic IP attached to the jump host."
  value       = aws_eip.jump_host.public_ip
}
