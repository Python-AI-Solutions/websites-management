variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_location" {
  description = "Location (zone or region) for the GKE cluster"
  type        = string
}

variable "enable_autoscaling" {
  description = "Enable autoscaling on the node pool"
  type        = bool
}

variable "autoscaling_min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
}

variable "autoscaling_max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
}

variable "node_count" {
  description = "Number of nodes in the default node pool (used if autoscaling is disabled)"
  type        = number
}

variable "node_disk_size_gb" {
  description = "Boot disk size (GB) for GKE nodes"
  type        = number
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
}

variable "service_account_email" {
  description = "Service account email to attach to GKE nodes"
  type        = string
}
