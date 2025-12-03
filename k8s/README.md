# Kubernetes Infrastructure - Terraform Code

This directory contains the infrastructure-as-code for deploying a production Kubernetes cluster using Terraform and WireGuard VPN.

## Quick Links

👉 **[Start here: Root Project README](../README.md)**

📚 **Documentation:**
- [Deployment Guide](../docs/infrastructure/setup.md) - How to deploy
- [Architecture](../docs/infrastructure/architecture.md) - System design
- [Security](../docs/infrastructure/security.md) - Security practices
- [Configuration](../docs/infrastructure/config.md) - Terraform config reference

📋 **[Contributing Guidelines](../CONTRIBUTING.md)** - How to contribute

## What's In This Directory

```
k8s/
├── main.tf                      ← Main infrastructure
├── variables.tf                 ← Variable definitions
├── outputs.tf                   ← Output values (kubeconfig, etc.)
├── terraform.tfvars.example     ← Configuration template (copy to terraform.tfvars)
├── .gitignore                   ← Secret protection
├── WIREGUARD_ARCHITECTURE.md    ← WireGuard network topology
├── apply.sh                     ← Helper script
├── aws/                         ← AWS resources (bastion, VPC)
├── debian/                      ← Debian host setup (Kubernetes node)
├── kubernetes/                  ← Kubernetes configuration (kubeadm, addons)
└── platform/                    ← Optional services (ArgoCD, MLflow, Traefik)
```

## Key Files

| File | Purpose |
|------|---------|
| `main.tf` | Main infrastructure configuration |
| `variables.tf` | Input variables definitions |
| `outputs.tf` | Output values (like kubeconfig) |
| `terraform.tfvars.example` | Configuration template - copy and edit this |
| `.gitignore` | Protects secrets from git |
| `WIREGUARD_ARCHITECTURE.md` | WireGuard VPN design details |

## Getting Started

### 1. Read the Documentation

Start with the deployment guide to understand what you're deploying:

```bash
# Read these in order:
cat ../docs/infrastructure/README.md      # Overview
cat ../docs/infrastructure/architecture.md  # System design
cat ../docs/infrastructure/setup.md       # Deployment guide
```

### 2. Configure

```bash
# Create your configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

See [../docs/infrastructure/config.md](../docs/infrastructure/config.md) for detailed explanations.

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan -out=tfplan

# Deploy (15-20 minutes)
./apply.sh
# or manually: terraform apply tfplan
```

See [../docs/infrastructure/setup.md](../docs/infrastructure/setup.md) for complete steps.

## File Organization

### AWS Resources (`aws/`)
- EC2 instances (bastion jump host)
- Security groups
- VPC configuration
- WireGuard VPN setup

### Debian Host (`debian/`)
- SSH configuration
- WireGuard client setup
- FRP emergency access
- System hardening

### Kubernetes (`kubernetes/`)
- kubeadm cluster bootstrap
- Cilium CNI setup
- Traefik ingress controller
- cert-manager TLS
- local-path-provisioner storage
- API audit logging
- RBAC configuration

### Optional Services (`platform/`)
- **ArgoCD** - GitOps deployment
- **MLflow** - ML experiment tracking (example only)
- **Traefik Sites** - Ingress configuration

## Important Notes

### Security

- **Never commit `terraform.tfvars`** - it contains secrets
- Always keep `terraform.tfvars` protected (chmod 600)
- Use `.gitignore` to protect sensitive files
- See [../docs/infrastructure/security.md](../docs/infrastructure/security.md) for security details

### WireGuard

- All access to the cluster goes through WireGuard VPN
- Keys are in `terraform.tfvars` (not committed to git)
- See `WIREGUARD_ARCHITECTURE.md` for network topology
- Each team member needs their own key pair

### SSH Agent

- SSH keys must be loaded in your agent before running Terraform
- Use `ssh-add -L` to verify keys are loaded
- This is required for Terraform to connect and configure hosts

## Troubleshooting

### Deployment Issues

See [../docs/infrastructure/setup.md](../docs/infrastructure/setup.md) - Troubleshooting section

### Configuration Questions

See [../docs/infrastructure/config.md](../docs/infrastructure/config.md)

### Security Questions

See [../docs/infrastructure/security.md](../docs/infrastructure/security.md)

### Architecture Questions

See [../docs/infrastructure/architecture.md](../docs/infrastructure/architecture.md)

## Contributing

Want to improve the infrastructure code?

1. Read [../CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines
2. Follow the development process
3. Test your changes
4. Submit a pull request

## Support

- **Project overview**: See [../README.md](../README.md)
- **Infrastructure docs**: See [../docs/infrastructure/](../docs/infrastructure/)
- **Website docs**: See [../docs/websites/](../docs/websites/)
- **Contributing**: See [../CONTRIBUTING.md](../CONTRIBUTING.md)

---

**Ready to deploy?** → [../docs/infrastructure/setup.md](../docs/infrastructure/setup.md)

**Need configuration help?** → [../docs/infrastructure/config.md](../docs/infrastructure/config.md)

**Have security questions?** → [../docs/infrastructure/security.md](../docs/infrastructure/security.md)
