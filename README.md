# Websites Management - Full Stack

Complete infrastructure and website deployment system using **Kubernetes**, **Terraform**, **WireGuard**, and modern DevOps practices.

This repository contains everything needed to deploy and manage a production Kubernetes infrastructure plus multiple websites.

## What's Inside

### 🏗️ Infrastructure (Kubernetes)
- **Terraform IaC** - Complete infrastructure-as-code for AWS + Kubernetes
- **WireGuard VPN** - Secure encrypted access to cluster
- **Single-node Kubernetes** - Production-ready k8s cluster with security hardening
- **Security First** - Etcd encryption, audit logging, RBAC

### 🌐 Websites  
- Multiple website projects deployed via Kubernetes
- Static site deployment to Cloudflare Pages
- DNS management and configuration

### 📚 Documentation
- Step-by-step deployment guides
- Security practices and hardening
- Architecture and design decisions
- Configuration reference

## Quick Start

### For Infrastructure Deployment

```bash
# 1. Read the infrastructure documentation
cat docs/infrastructure/README.md

# 2. Follow deployment guide
cat docs/infrastructure/setup.md

# 3. Configure your environment
cp k8s/terraform.tfvars.example k8s/terraform.tfvars
# Edit with your values
```

### For Website Deployment

See [docs/websites/README.md](docs/websites/README.md) for deployment instructions.

## Documentation

Start here based on your needs:

| Need | Documentation |
|------|---|
| **Deploy Kubernetes infrastructure** | [docs/infrastructure/setup.md](docs/infrastructure/setup.md) |
| **Understand the architecture** | [docs/infrastructure/architecture.md](docs/infrastructure/architecture.md) |
| **Security questions** | [docs/infrastructure/security.md](docs/infrastructure/security.md) |
| **Configure Terraform** | [docs/infrastructure/config.md](docs/infrastructure/config.md) |
| **Troubleshoot issues** | [docs/infrastructure/TROUBLESHOOTING.md](docs/infrastructure/TROUBLESHOOTING.md) |
| **Operational procedures** | [docs/infrastructure/RUNBOOKS.md](docs/infrastructure/RUNBOOKS.md) |
| **Deploy websites** | [docs/websites/README.md](docs/websites/README.md) |
| **How to contribute** | [CONTRIBUTING.md](CONTRIBUTING.md) |
| **Project overview** | [docs/README.md](docs/README.md) |

## Project Structure

```
websites-management/
├── README.md                    ← You are here
├── LICENSE                      ← MIT License
├── CONTRIBUTING.md              ← How to contribute
├── docs/                        ← Documentation
│   ├── README.md                ← Navigation
│   ├── infrastructure/           ← Kubernetes/infrastructure docs
│   │   ├── setup.md
│   │   ├── security.md
│   │   ├── architecture.md
│   │   └── config.md
│   └── websites/                ← Website deployment docs
│       └── README.md
├── k8s/                         ← Kubernetes infrastructure code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── CONTRIBUTING.md          ← k8s-specific guidelines
│   ├── LICENSE
│   ├── aws/                     ← AWS resources
│   ├── debian/                  ← Debian host setup
│   ├── kubernetes/              ← K8s configuration
│   └── platform/                ← Optional services (ArgoCD, MLflow, etc.)
├── sites/                       ← Website deployment files
└── [other project files]
```

## Features

✅ **Infrastructure as Code** - Everything version-controlled and reproducible  
✅ **Secure by Default** - WireGuard VPN, encryption, audit logging  
✅ **Production Ready** - Cilium, Traefik, cert-manager, persistent storage  
✅ **Documented** - Comprehensive guides and architecture docs  
✅ **Team-Friendly** - Simple configuration, clear workflows  

## Security

Security is built-in at every layer:

- **Network**: WireGuard VPN encryption
- **Storage**: Etcd encryption at rest (AES-CBC 256-bit)
- **API**: Kubernetes audit logging for compliance
- **Credentials**: All secrets externalized from code
- **SSH**: Key-based authentication, hardened access

See [docs/infrastructure/security.md](docs/infrastructure/security.md) for details.

## Prerequisites

- **Terraform** >= 1.5 (or OpenTofu >= 1.5)
- **kubectl** >= 1.27
- **AWS account** with credentials configured
- **SSH keys** loaded in agent
- **WireGuard** (optional, for VPN access)

## Getting Started

**Read these in order:**

1. [docs/README.md](docs/README.md) - Documentation index
2. [docs/infrastructure/README.md](docs/infrastructure/README.md) - Infrastructure overview
3. [docs/infrastructure/setup.md](docs/infrastructure/setup.md) - Deployment guide

**Then:**

4. [docs/infrastructure/config.md](docs/infrastructure/config.md) - Configure your deployment
5. Run the deployment steps from [docs/infrastructure/setup.md](docs/infrastructure/setup.md)

## Architecture

### High-Level

```
Your Machine → WireGuard VPN → Bastion → Kubernetes Cluster
                  (encrypted)   (jump)    (workloads)
```

### Components

- **Bastion** - AWS EC2 jump host with WireGuard VPN endpoint
- **Kubernetes Node** - Debian host running single-node Kubernetes cluster
- **CNI** - Cilium for network plugin and security
- **Ingress** - Traefik for HTTP/HTTPS routing
- **Certificates** - cert-manager with Let's Encrypt
- **Storage** - local-path-provisioner for persistent volumes

See [docs/infrastructure/architecture.md](docs/infrastructure/architecture.md) for complete design.

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Development guidelines
- Testing procedures
- Code quality standards
- Security considerations
- Pull request process

## Support

**Questions or issues?**

1. Check the [documentation index](docs/README.md)
2. Read relevant guide (setup, security, config, etc.)
3. Review [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
4. Create an issue with details

## License

MIT License - See [LICENSE](LICENSE) for details.

---

**Ready to deploy?** Start with [docs/infrastructure/setup.md](docs/infrastructure/setup.md)

**Want to understand first?** Read [docs/infrastructure/architecture.md](docs/infrastructure/architecture.md)

**Need to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md)
