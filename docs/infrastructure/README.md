# Infrastructure Documentation

Complete documentation for the Kubernetes infrastructure deployment.

## Quick Navigation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[setup.md](./setup.md)** | How to deploy step-by-step | 15 min |
| **[architecture.md](./architecture.md)** | System design and components | 10 min |
| **[security.md](./security.md)** | Security practices and hardening | 10 min |
| **[config.md](./config.md)** | Terraform configuration reference | 15 min |
| **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** | Common issues and solutions | 5 min |
| **[RUNBOOKS.md](./RUNBOOKS.md)** | Operational procedures | 10 min |

## Overview

This directory contains comprehensive documentation for deploying a production-grade Kubernetes cluster using Terraform and WireGuard VPN.

### What You'll Deploy

✅ **AWS EC2 Jump Host (Bastion)** - Entry point to infrastructure  
✅ **Debian Host** - Runs Kubernetes single-node cluster  
✅ **WireGuard VPN** - Secure encrypted access tunnel  
✅ **Kubernetes Cluster** - With Cilium, Traefik, cert-manager  
✅ **Security Hardening** - Etcd encryption, audit logging, RBAC  

### Time & Complexity

- **Deployment Time:** 15-20 minutes
- **Configuration Time:** 10-15 minutes
- **Complexity:** Intermediate (Terraform, Kubernetes basics helpful)

## Getting Started (3 Steps)

### 1. Understand the Design

Read [architecture.md](./architecture.md) to understand:
- How components connect
- Security layers
- Network topology
- WireGuard VPN setup

### 2. Prepare Configuration

Follow [config.md](./config.md) to:
- Generate WireGuard keys
- Set AWS credentials
- Configure team members
- Prepare terraform.tfvars

### 3. Deploy

Follow [setup.md](./setup.md) to:
- Run Terraform
- Verify cluster is running
- Access Kubernetes
- Troubleshoot if needed

## By Task

### I want to deploy right now
→ [setup.md](./setup.md)

### I want to understand the design first
→ [architecture.md](./architecture.md)

### I have security questions
→ [security.md](./security.md)

### I'm stuck on configuration
→ [config.md](./config.md)

### Something is broken or not working
→ [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

### I need to run operational procedures
→ [RUNBOOKS.md](./RUNBOOKS.md)

## Prerequisites

**Software:**
- Terraform >= 1.5 (or OpenTofu >= 1.5)
- kubectl >= 1.27
- SSH client
- WireGuard (optional)

**Accounts:**
- AWS account with EC2 permissions
- SSH key pairs generated

**Knowledge:**
- Basic Terraform understanding
- Basic Kubernetes concepts
- AWS familiarity helpful but not required

## Key Concepts

### Infrastructure as Code

Everything is defined in Terraform - reproducible, version-controlled, auditable.

### WireGuard VPN

Secure encrypted tunnel to access your Kubernetes cluster from anywhere.

### Single-Node Kubernetes

Single server running both control plane and worker pods - perfect for teams and small deployments.

### Security First

- Network isolation via VPN
- Encryption at rest (etcd)
- API audit logging
- RBAC and pod security

## File Structure

```
k8s/                           ← Infrastructure code
├── README.md                  ← k8s-specific README
├── main.tf                    ← Main infrastructure
├── variables.tf               ← Variable definitions
├── outputs.tf                 ← Output values
├── terraform.tfvars.example   ← Config template
├── CONTRIBUTING.md            ← k8s guidelines
├── LICENSE                    ← MIT License
├── aws/                       ← AWS resources
├── debian/                    ← Debian setup
├── kubernetes/                ← K8s configuration
└── platform/                  ← Optional services
```

## Support

**Questions or issues?**

1. Check troubleshooting in [setup.md](./setup.md)
2. Review [architecture.md](./architecture.md) for design details
3. See [security.md](./security.md) for security questions
4. Refer to [config.md](./config.md) for configuration help

---

**Ready to start?** → [setup.md](./setup.md)

**Want to understand first?** → [architecture.md](./architecture.md)

**Have config questions?** → [config.md](./config.md)

