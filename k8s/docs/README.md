# Documentation Index

Navigate the infrastructure documentation:

## Quick Navigation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[setup.md](./setup.md)** | How to deploy the infrastructure | 15 min |
| **[architecture.md](./architecture.md)** | How everything is designed | 10 min |
| **[security.md](./security.md)** | Security practices and hardening | 10 min |
| **[config.md](./config.md)** | Configuration reference guide | 15 min |

## By Use Case

### I want to deploy
→ Start: [setup.md](./setup.md)

### I want to understand the design
→ Read: [architecture.md](./architecture.md)

### I need to configure terraform.tfvars
→ Reference: [config.md](./config.md)

### I have security questions
→ See: [security.md](./security.md)

### I need to contribute
→ See: [../CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Document Descriptions

### setup.md - Deployment Guide

**What:** Step-by-step instructions to deploy the infrastructure

**Includes:**
- Prerequisites and tool installation
- AWS credential setup
- WireGuard key generation
- Configuration walkthrough
- Deployment commands
- Verification steps
- Troubleshooting common issues

**Read this if:** You're deploying for the first time

### architecture.md - System Design

**What:** Complete overview of how the system works

**Includes:**
- High-level architecture diagram
- Network topology
- Security layers
- Component details
- Data flow examples
- Scaling considerations

**Read this if:** You want to understand the design before deploying

### security.md - Security Practices

**What:** Security implementation and best practices

**Includes:**
- Secret management (terraform.tfvars)
- Network security (WireGuard)
- Encryption (at-rest and in-transit)
- Kubernetes RBAC and audit logging
- Emergency access procedures
- Security checklist
- Monitoring recommendations

**Read this if:** You have security questions or need to harden the setup

### config.md - Configuration Reference

**What:** Detailed explanation of every terraform.tfvars setting

**Includes:**
- WireGuard keys explanation
- SSH key setup
- AWS configuration
- Team member setup
- IP allocation
- Feature flags
- Validation checks
- Complete example

**Read this if:** You're filling in terraform.tfvars or need to understand a setting

---

## Full Document Structure

```
k8s/
├── README.md                      ← Main introduction (start here!)
├── docs/
│   ├── README.md                  ← This file (navigation)
│   ├── setup.md                   ← Deployment guide
│   ├── architecture.md            ← System design
│   ├── security.md                ← Security practices
│   └── config.md                  ← Configuration reference
├── CONTRIBUTING.md                ← How to contribute
├── LICENSE                        ← MIT License
├── terraform.tfvars.example       ← Config template
├── main.tf, variables.tf, outputs.tf
├── aws/, debian/, kubernetes/
└── platform/                      ← Optional services
    ├── README.md
    ├── argocd/
    ├── mlflow/
    └── traefik-sites/
```

## Common Questions

**Q: Where do I start?**  
A: Read [../README.md](../README.md) first, then go to [setup.md](./setup.md)

**Q: How do I configure the deployment?**  
A: Copy `terraform.tfvars.example` and follow [config.md](./config.md)

**Q: What about security?**  
A: Review [security.md](./security.md) for all practices and recommendations

**Q: I'm stuck on deployment**  
A: Check troubleshooting section in [setup.md](./setup.md)

**Q: How does the network work?**  
A: See "Network Topology" in [architecture.md](./architecture.md)

**Q: Can I add more nodes?**  
A: See "Scaling Considerations" in [architecture.md](./architecture.md)

**Q: What should I back up?**  
A: See "Disaster Recovery" in [architecture.md](./architecture.md)

---

## Before Deploying

1. ✅ Read [../README.md](../README.md) for overview
2. ✅ Review [architecture.md](./architecture.md) to understand design
3. ✅ Read [setup.md](./setup.md) for deployment steps
4. ✅ Prepare configuration using [config.md](./config.md)
5. ✅ Review [security.md](./security.md) for security checklist

## Support

Can't find what you're looking for?

- Check the **Table of Contents** in each document
- Search for keywords (Ctrl+F)
- Read the main [../README.md](../README.md)
- Review [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines

---

**Ready to deploy?** → [setup.md](./setup.md)

**Ready to understand?** → [architecture.md](./architecture.md)

**Ready to configure?** → [config.md](./config.md)

