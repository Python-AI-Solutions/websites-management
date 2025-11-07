output "gke_cluster_name" {
  description = "Name of the created GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_location" {
  description = "Location (zone/region) of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "gke_node_pool_name" {
  description = "Name of the GKE node pool"
  value       = google_container_node_pool.primary_nodes.name
}
