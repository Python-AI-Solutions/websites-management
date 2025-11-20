terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_eip" "bastion" {
  domain = "vpc"
  tags   = var.eip_tags

  lifecycle {
    prevent_destroy = true
  }
}

output "bastion_allocation_id" {
  description = "Allocation ID for the reusable bastion EIP."
  value       = aws_eip.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP associated with the bastion EIP."
  value       = aws_eip.bastion.public_ip
}
