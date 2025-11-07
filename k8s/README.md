# Kubernetes Single-Node Cluster Setup

This OpenTofu/Terraform stack bootstraps a single-node Kubernetes cluster on a remote Debian host using kubeadm, containerd, and essential add-ons.

## Prerequisites

- SSH access to a fresh Debian host with passwordless sudo
- OpenTofu ≥ 1.5.0 (or Terraform ≥ 1.0)
- `kubectl` installed locally
- Outbound internet connectivity from the target host

## Components Installed

- **Container Runtime**: containerd with SystemdCgroup
- **Kubernetes**: Single-node control plane via kubeadm (also schedules workloads)
- **CNI**: Cilium (with kube-proxy replacement)
- **Ingress**: Traefik (exposed on host ports 80/443)
- **TLS**: cert-manager with CRD installation
- **Storage**: local-path-provisioner (default StorageClass)

## Quick Start

```bash
cd k8s
tofu init
tofu apply \
  -var 'host=YOUR_SERVER_IP' \
  -var 'ssh_user=sysadmin' \
  -var 'ssh_private_key_path=~/.ssh/id_ed25519' \
  -var 'cluster_name=xps'

# After successful apply:
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
```

## Verify Add-ons

```bash
kubectl -n kube-system get ds cilium
kubectl -n traefik get deploy traefik
kubectl -n cert-manager get pods
kubectl get storageclass
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `host` | Remote host IP/DNS (required) | - |
| `ssh_user` | SSH username | `sysadmin` |
| `ssh_private_key_path` | Path to SSH private key | `~/.ssh/id_ed25519` |
| `cluster_name` | Kubernetes cluster name | `xps-cluster` |
| `kubernetes_version` | Kubernetes version | `1.30.5` |
| `pod_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |
| `cilium_chart_version` | Cilium Helm chart version | `1.16.3` |
| `traefik_chart_version` | Traefik Helm chart version | `32.1.0` |
| `cert_manager_chart_version` | cert-manager Helm chart version | `v1.16.1` |
| `local_path_provisioner_chart_version` | local-path-provisioner version | `0.0.28` |

## Bastion/Jump Host

If your host requires access through a bastion:

```bash
tofu apply \
  -var 'host=YOUR_SERVER_IP' \
  -var 'bastion_host=BASTION_IP' \
  -var 'bastion_user=ubuntu' \
  -var 'bastion_private_key_path=~/.ssh/bastion_key'
```

## Optional: Let's Encrypt Certificate

To enable automatic TLS certificates:

```bash
tofu apply \
  -var 'acme_email=your-email@example.com' \
  -var 'enable_letsencrypt_staging=false'  # Use 'true' for testing
```

This creates a ClusterIssuer for cert-manager. Use it in your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # or letsencrypt-staging
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - example.com
      secretName: example-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
```

## Port-forward Traefik Dashboard (Optional)

```bash
kubectl -n traefik port-forward deploy/traefik 9000:9000
# Access at http://localhost:9000/dashboard/
```

## Remote State (Future)

Currently uses local backend. To migrate to remote state:

1. Create a GCS bucket or S3 bucket for state storage
2. Update `main.tf` backend configuration
3. Run `tofu init -migrate-state`

## Troubleshooting

### Check cluster initialization
```bash
kubectl get nodes
kubectl get cs  # Component status
```

### Check CNI (Cilium)
```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system logs -l k8s-app=cilium
```

### Check Ingress (Traefik)
```bash
kubectl -n traefik get all
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
```

### Check cert-manager
```bash
kubectl -n cert-manager get all
kubectl get clusterissuer
```

## Clean Up

To destroy the cluster (this is destructive):
```bash
tofu destroy
```

Note: This will not clean up the Debian host itself. To fully reset, you may need to:
- Run `kubeadm reset` on the host
- Remove `/etc/kubernetes/`, `/var/lib/kubelet/`, `/etc/cni/`
- Restart the host

## Security Notes

- The kubeconfig file contains admin credentials - keep it secure
- Consider implementing RBAC for production use
- Enable audit logging for compliance requirements
- Use network policies to restrict pod-to-pod communication
