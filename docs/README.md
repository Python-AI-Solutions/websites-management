# Documentation Index

Complete navigation for all project documentation.

## Quick Navigation

### 🏗️ Infrastructure & Kubernetes

**New to this project?** Start here:

1. [infrastructure/README.md](infrastructure/README.md) - Infrastructure overview
2. [infrastructure/setup.md](infrastructure/setup.md) - How to deploy (15-20 minutes)
3. [infrastructure/architecture.md](infrastructure/architecture.md) - How it all works
4. [infrastructure/security.md](infrastructure/security.md) - Security practices
5. [infrastructure/config.md](infrastructure/config.md) - Configuration guide

### 🌐 Websites

See [websites/README.md](websites/README.md) for website deployment documentation.

### 📚 General

- [../README.md](../README.md) - Project overview
- [../CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute

---

## By Task

### I want to deploy the infrastructure
→ [infrastructure/setup.md](infrastructure/setup.md)

### I want to understand the design
→ [infrastructure/architecture.md](infrastructure/architecture.md)

### I have security questions
→ [infrastructure/security.md](infrastructure/security.md)

### I need to configure Terraform
→ [infrastructure/config.md](infrastructure/config.md)

### I want to deploy a website
→ [websites/README.md](websites/README.md)

### I want to contribute
→ [../CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Documentation Structure

```
docs/
├── README.md                 ← This file (navigation)
├── infrastructure/           ← Kubernetes & infrastructure
│   ├── README.md             ← Infrastructure overview
│   ├── setup.md              ← Deployment guide (START HERE)
│   ├── architecture.md       ← System design
│   ├── security.md           ← Security practices
│   └── config.md             ← Configuration reference
└── websites/                 ← Website deployment
    └── README.md             ← Website docs
```

---

## Full Documentation Map

### Infrastructure Documentation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[infrastructure/setup.md](infrastructure/setup.md)** | Step-by-step deployment guide | 15 min |
| **[infrastructure/architecture.md](infrastructure/architecture.md)** | System design and topology | 10 min |
| **[infrastructure/security.md](infrastructure/security.md)** | Security practices and hardening | 10 min |
| **[infrastructure/config.md](infrastructure/config.md)** | Terraform configuration reference | 15 min |

### Website Documentation

| Document | Purpose |
|----------|---------|
| **[websites/README.md](websites/README.md)** | Website deployment guide |

### Project Documentation

| Document | Purpose |
|----------|---------|
| **[../README.md](../README.md)** | Project overview |
| **[../CONTRIBUTING.md](../CONTRIBUTING.md)** | Contribution guidelines |
| **[../LICENSE](../LICENSE)** | MIT License |

---

## Before You Start

✅ **Prerequisites:**
- Terraform >= 1.5 (or OpenTofu)
- kubectl >= 1.27
- AWS account configured
- SSH keys in agent

✅ **Recommended Reading:**
1. Project [README.md](../README.md)
2. Infrastructure [README.md](infrastructure/README.md)
3. Deployment [setup.md](infrastructure/setup.md)

---

## Troubleshooting

**Can't find what you need?**

1. Use Ctrl+F to search this page
2. Check the relevant documentation file
3. Review [../README.md](../README.md) for overview
4. See [../CONTRIBUTING.md](../CONTRIBUTING.md) for support

---

**Ready to deploy?** → [infrastructure/setup.md](infrastructure/setup.md)

**Ready to contribute?** → [../CONTRIBUTING.md](../CONTRIBUTING.md)
