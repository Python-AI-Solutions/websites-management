variable "eip_tags" {
  description = "Tags to apply to the bastion EIP."
  type        = map(string)
  default     = {}
}
