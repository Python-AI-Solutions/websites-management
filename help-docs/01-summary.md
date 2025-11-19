# Summary - Infrastructure Deployment Strategy

**Date:** 2025-11-18
**Topic:** Kubernetes & Debian Infrastructure Deployment Plan
**Status:** Complete - Ready for Implementation

---

## 🎯 Core Problem Statement

The infrastructure is currently blocked by a chicken-and-egg problem:
- Debian host needs VPN access to be configured
- VPN access cannot be set up without accessing the Debian host
- WireGuard IP is misconfigured (10.99.0.2 instead of 10.99.0.20)
- No way to reach the host to fix it

**Solution:** Use FRP (Fast Reverse Proxy) as emergency access mechanism, fix configuration via Infrastructure as Code (Terraform), then continue with normal VPN access.

---

## ✅ Key Decisions & Approvals

### Architecture Approach
- ✅ Use FRP as temporary emergency breakglass access
- ✅ Implement all changes via Infrastructure as Code (Terraform)
- ✅ Single `tofu apply` command orchestrates everything
- ✅ Health check logic auto-enables FRP when needed

### Technology Choices
- ✅ Google Secret Manager (NOT AWS Secrets Manager) for credential rotation
- ✅ Manual Kubernetes deployment (both team members must understand each step)
- ✅ WireGuard for primary VPN access

### Phase 2A - Advanced Hardening (Approved)
- ✅ OIDC + RBAC (3h) - SSO-based access control
- ✅ Network Policies (2h) - Zero-trust pod communication
- ✅ Traefik Hardening (2h) - Ingress layer security
- ✅ Pod Security (2h) - Non-root container requirements (with acknowledgment of complexity)

### Rejected/Deferred Components
- ❌ CI/CD Image Signing - "Not a priority at all"
- ⏸️ Two-Person Approval Requirements - "Not at the moment" (revisit later)

---

## 🎯 Three Core Priorities (This Phase)

1. **Get MLflow working** - ML model tracking and deployment
2. **Deploy niivue app to Kubernetes** - Web application on K8s cluster
3. **Shut down GKE** - Stop paying 200-300 EUR/month

---

## 🏗️ Infrastructure Architecture

### Module Structure
```
Single tofu apply orchestrates three modules:
├── AWS Module: Bastion host + WireGuard VPN server + FRP server
├── Debian Module: VPN peer configuration + FRP client
└── Kubernetes Module: Cluster on Debian with hardening
```

### Deployment Intelligence
- Health check runs: "Can we reach Debian via WireGuard?"
- If YES → Normal deployment, FRP disabled
- If NO → Auto-enable FRP for emergency access

### Key Infrastructure Improvements
- VPN IP fix: 10.99.0.2 → 10.99.0.20 (via Terraform)
- WireGuard for primary access
- FRP for emergency recovery
- Etcd encryption (AES-CBC 256-bit)
- API audit logging
- SSH restricted to VPN only

---

## 📋 Implementation Requirements

### Terraform Configuration
- All changes via Infrastructure as Code (no manual commands except emergencies)
- Module-based structure with proper dependencies
- State stored in encrypted GCS backend
- Single directory structure (k8s/) for deployment

### Security Hardening (Phase 1)
- ✅ WireGuard encryption for VPN access
- ✅ Port restrictions (iptables rules)
- ✅ Etcd secrets encryption at rest
- ✅ API server audit logging
- ✅ SSH only from VPN

### Documentation & Audit
- ✅ Deployment procedures documented
- ✅ Emergency runbooks provided
- ✅ Change tracking (audit trail)
- ✅ Pre-deployment verification checklists

---

## 📊 Effort & Timeline

### This Week (Critical Path)
- Directory merge: 2-3 hours
- FRP implementation: 3-4 hours
- Deployment: 0.5-1 hour
- MLflow setup: 2-3 hours
- niivue deployment: 1-2 hours
- **Total: 9-13 hours**

### Following Week (Phase 2A)
- OIDC + RBAC: 3 hours
- Network Policies: 2 hours
- Traefik Hardening: 2 hours
- Pod Security: 2 hours
- **Total: 9 hours**

---

## 💡 Important Principles

### Manual Until Comfortable
Both team members must understand each step before automation. No automation of processes that aren't fully understood by both parties.

### Everything as Code
- No manual VPN configuration
- No manual FRP toggles
- All changes via Terraform/git
- Reproducible and auditable

### Transparency & Communication
- Document all decisions
- Clear procedure for emergency access
- Runbooks for troubleshooting
- Audit trail of all changes

---

## 🔄 Expected Outcomes

**After Implementation:**
- Infrastructure deployable with single command
- Debian accessible (normal or emergency FRP)
- Kubernetes cluster operational with hardening
- MLflow and niivue deployed and working
- GKE can be shut down (cost savings achieved)
- Phase 1 ready for sign-off

**Security Grade:** 🟡 **B** (Staging/Development Ready)

---

## 📚 Related Documents

- **ACTION_PLAN.md** - Detailed implementation steps and priorities
- **EXECUTION_SUMMARY.md** - What was built, current status
- **NEXT_STEPS.md** - Required inputs and actions for both parties

