# 🚀 Infrastructure Repository

This repository contains production-grade Kubernetes infrastructure-as-code demonstrating modern DevOps practices.

## What's Inside

**Complete Kubernetes deployment** from bare infrastructure to production-ready cluster:
- AWS EC2 jump host (bastion)
- Debian host via WireGuard VPN
- Single-node Kubernetes cluster
- Cilium CNI, Traefik ingress, cert-manager TLS
- Comprehensive security hardening & audit logging

## Quick Links

- **[README.md](./README.md)** - Overview of components and architecture
- **[SETUP.md](./SETUP.md)** - Complete deployment guide (15-20 minutes)
- **[SECURITY.md](./SECURITY.md)** - Security practices, hardening, audit logging
- **[WIREGUARD_ARCHITECTURE.md](./WIREGUARD_ARCHITECTURE.md)** - Network topology

## Key Features

✅ **Infrastructure as Code**
- Everything defined in Terraform
- Reproducible deployments
- Version controlled

✅ **Secure by Default**
- WireGuard VPN for all cluster access
- Etcd encryption at rest (AES-CBC 256-bit)
- API audit logging for compliance
- SSH hardening + key-based auth only
- Emergency access via FRP reverse proxy

✅ **Production Ready**
- Cilium network plugin with kube-proxy replacement
- Traefik ingress controller (ports 80/443)
- cert-manager with Let's Encrypt integration
- local-path-provisioner for persistent storage

✅ **Observable**
- Complete Kubernetes API audit logging
- Security group logging
- Application access logs via Traefik

## Getting Started

### Prerequisites
- Terraform >= 1.5
- kubectl >= 1.27
- WireGuard (optional, for VPN access)
- AWS account and credentials

### Deploy in 3 Steps

```bash
# 1. Clone and configure
git clone https://github.com/yourusername/infrastructure.git
cd infrastructure/k8s
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy
terraform init
./apply.sh

# 3. Access cluster
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

**Full details:** See [SETUP.md](./SETUP.md)

## Architecture

```
┌─────────────────────────────────────┐
│        Your Machine                 │
│   (with SSH keys loaded)            │
└──────────────┬──────────────────────┘
               │ WireGuard UDP:51820
               │ (encrypted tunnel)
               ▼
┌──────────────────────────────────┐
│   AWS EC2 Bastion Jump Host      │
│   (Public IP: accessible)        │
│   WireGuard Server: 10.99.0.1    │
│   - SSH access point             │
│   - WireGuard server             │
│   - FRP emergency tunnel         │
└──────────────┬───────────────────┘
               │ Private Network
               │ (10.99.0.0/24)
               ▼
┌──────────────────────────────────┐
│   Debian Host                    │
│   (Private IP: 192.168.1.123)    │
│   WireGuard Peer: 10.99.0.2      │
│   - Kubernetes Control Plane     │
│   - etcd (encrypted)             │
│   - API Server                   │
│   - kubelet                      │
│   - Cilium networking            │
└──────────────────────────────────┘
```

All communication encrypted:
- **WireGuard tunnel:** ChaCha20-Poly1305 encryption
- **Etcd storage:** AES-CBC 256-bit encryption
- **API TLS:** 1.2+

## Features Demonstrated

### Infrastructure Management
- [x] Terraform modules for separation of concerns
- [x] Remote state backend (GCS)
- [x] Parameterized configuration
- [x] Automatic resource cleanup

### Kubernetes Hardening
- [x] Etcd encryption at rest
- [x] API server audit logging
- [x] RBAC configuration
- [x] Network policies (Cilium)
- [x] Pod security standards
- [x] TLS certificates (cert-manager)

### Network Security
- [x] VPN-only cluster access (WireGuard)
- [x] SSH access restricted to VPN
- [x] Security groups with least privilege
- [x] Firewall rules (iptables)
- [x] DDoS protection (WireGuard rate limiting)
- [x] Fail2ban for SSH brute-force protection

### DevOps Best Practices
- [x] Infrastructure as Code
- [x] Automated deployment
- [x] Health checks
- [x] Monitoring endpoints
- [x] Disaster recovery
- [x] Git-based workflows

## Project Structure

```
k8s/
├── README.md                    # Main documentation
├── SETUP.md                     # Deployment guide
├── SECURITY.md                  # Security practices
├── WIREGUARD_ARCHITECTURE.md    # Network details
├── terraform.tfvars.example     # Configuration template
├── .gitignore                   # Git safety rules
│
├── main.tf                      # Root orchestration
├── variables.tf                 # Configuration variables
├── outputs.tf                   # Output values
│
├── aws/                         # AWS infrastructure
│   ├── main.tf                  # EC2, security groups, WireGuard
│   ├── variables.tf
│   ├── outputs.tf
│   ├── frp.tf                   # Emergency access
│   └── scripts/
│       ├── wireguard-bootstrap.sh
│       └── local-wireguard-setup-on-macos.py
│
├── debian/                      # Debian host setup
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── kubernetes/                  # K8s cluster deployment
│   ├── main.tf                  # kubeadm initialization
│   ├── variables.tf
│   ├── outputs.tf
│   └── kubeadm-config.yaml.tmpl # Cluster bootstrap template
│
└── platform/                    # Additional services
    ├── argocd/                  # ArgoCD deployment
    ├── mlflow/                  # MLFlow (experimental)
    └── traefik-sites/           # Ingress configuration
```

## What You Can Learn

This repository demonstrates:

1. **Terraform Modules:** Organizing infrastructure into reusable, testable units
2. **Security Layers:** Defense in depth with VPN, encryption, and hardening
3. **Kubernetes Bootstrapping:** Using kubeadm to set up production clusters
4. **Network Architecture:** WireGuard-based private networks
5. **API Audit Logging:** Compliance and security monitoring
6. **Disaster Recovery:** Emergency access mechanisms (FRP)

## Security Considerations

This infrastructure includes several security features:

- **Network Isolation:** WireGuard VPN gates all access
- **Encryption:** AES-256 for etcd, ChaCha20 for WireGuard
- **Audit Trail:** Complete API request/response logging
- **Access Control:** SSH hardened, RBAC enabled
- **Emergency Access:** FRP for breakglass scenarios

**⚠️ Important:** Never commit sensitive files:
- `terraform.tfvars` (contains secrets)
- `kubeconfig` (cluster admin credentials)
- AWS/GCP credentials
- SSH private keys

See [SECURITY.md](./SECURITY.md) for detailed security practices.

## Customization

You can easily customize:

- **Kubernetes Version:** Update `kubernetes_version` variable
- **Cluster Size:** Add nodes using kubeadm join (see comments in code)
- **Networking:** Modify pod/service CIDRs
- **Ingress:** Add more Traefik IngressRoutes
- **Storage:** Configure PVC backend options

See [SETUP.md](./SETUP.md) for detailed customization options.

## Troubleshooting

Common issues and solutions:

```bash
# Can't SSH to cluster?
# → Verify WireGuard is connected: wg show

# Kubernetes API not responding?
# → Check pods: kubectl get pods -A
# → Check logs: kubectl logs -n kube-system -l component=kubelet

# Ingress not working?
# → Check Traefik: kubectl -n traefik get all
# → Check rules: kubectl describe ingress my-ingress
```

See [SETUP.md#Troubleshooting](./SETUP.md#troubleshooting) for detailed troubleshooting guide.

## Contributing

This is a portfolio/reference project. To use it:

1. **Clone:** `git clone https://github.com/yourusername/infrastructure.git`
2. **Configure:** Copy `terraform.tfvars.example` to `terraform.tfvars` and edit
3. **Deploy:** Run `./apply.sh` and follow output
4. **Customize:** Modify Terraform code for your needs

## License

[MIT License](LICENSE) - Feel free to use this infrastructure as a reference for your own projects.

## About

This infrastructure demonstrates professional DevOps practices including:
- Infrastructure as Code with Terraform
- Kubernetes deployment and hardening
- Network security with WireGuard VPN
- Comprehensive documentation
- Production-grade reliability

For details on architecture, deployment, and security practices, see the guides above.

---

## Next Steps

- 📖 **Learn:** Read [SETUP.md](./SETUP.md) for deployment guide
- 🔒 **Secure:** Review [SECURITY.md](./SECURITY.md) for security practices
- 🏗️ **Understand:** Check [WIREGUARD_ARCHITECTURE.md](./WIREGUARD_ARCHITECTURE.md) for network design
- 🚀 **Deploy:** Follow [SETUP.md](./SETUP.md) to deploy your own cluster

Questions? File an issue or check the documentation guides above.
