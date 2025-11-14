# Optional Features

This document describes optional features that can be added to the K8s setup.

## 1. Remote State Backend (Recommended for Team Collaboration)

### Why Use Remote State?
- **Collaboration**: Multiple team members can work on the same infrastructure
- **Safety**: State is stored centrally with versioning
- **Locking**: Prevents concurrent modifications

### How to Implement

See the `remote-state-setup/` directory for complete instructions.

**Quick Start:**

```bash
# Step 1: Create state storage
cd remote-state-setup
tofu init
tofu apply -var 'project_id=YOUR_PROJECT_ID'

# Step 2: Note the bucket name from output

# Step 3: Update ../main.tf backend configuration
# Replace:
backend "local" {}

# With (for GCS):
backend "gcs" {
  bucket = "YOUR-BUCKET-NAME"
  prefix = "k8s-cluster/terraform.tfstate"
}

# Step 4: Migrate state
cd ..
tofu init -migrate-state
```

---

## 2. Join Command Output (For Multi-Node Clusters)

### Why Use This?
- Useful if you plan to add worker nodes later
- Provides the exact command to join new nodes

### How to Implement

Add to `main.tf`:

```hcl
# Generate join command for adding worker nodes
resource "null_resource" "generate_join_command" {
  depends_on = [null_resource.k8s_init]
  
  provisioner "local-exec" {
    command = <<-EOT
      ssh ${var.ssh_user}@${var.host} \
        'sudo kubeadm token create --print-join-command' \
        > ${path.module}/join-command.txt
    EOT
  }
  
  # Add this trigger to regenerate if cluster changes
  triggers = {
    cluster_init = null_resource.k8s_init.id
  }
}

output "join_command_file" {
  description = "Location of the join command file"
  value       = "${path.module}/join-command.txt"
}
```

Add to `.gitignore`:
```
join-command.txt
```

**Usage:**
```bash
# After tofu apply, use the join command on worker nodes:
cat join-command.txt
# Output example:
# sudo kubeadm join 192.168.1.100:6443 --token abc123... --discovery-token-ca-cert-hash sha256:def456...
```

---

## 3. Monitoring Stack (Future Enhancement)

Consider adding:
- **Prometheus** for metrics collection
- **Grafana** for visualization
- **Loki** for log aggregation

This would be a separate Terraform module or Helm releases.

---

## 4. Network Policies

For production security, consider adding:
- Default deny-all policy
- Explicit allow policies per namespace
- Ingress/egress rules

Example:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## 5. Backup Strategy

Consider implementing:
- **Velero** for cluster backup/restore
- **etcd snapshots** for control plane data
- **PV backup** for persistent data

---

## Priority Recommendations

| Feature | Priority | Complexity | Benefit |
|---------|----------|------------|---------|
| Remote State | HIGH | Low | Essential for teams |
| Join Command | LOW | Very Low | Only if multi-node |
| Monitoring | MEDIUM | Medium | Important for ops |
| Network Policies | HIGH | Medium | Security essential |
| Backup | MEDIUM | Medium | Disaster recovery |
