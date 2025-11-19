# Action Plan - Implementation & Priorities

**Status:** Ready for Execution
**Last Updated:** 2025-11-19
**Owner:** Development Team

---

## 🎯 IMMEDIATE PRIORITIES (This Week)

### TASK 1: Design Debian Deployment Strategy ⭐ START HERE
**Priority:** CRITICAL
**Effort:** 2-3 hours
**Status:** Design phase

**Deliverable:** `k8s/DEBIAN_DEPLOYMENT_PLAN.md`
- Architecture overview (FRP emergency access workflow)
- IaC implementation strategy
- VPN peer configuration (10.99.0.20)
- Deployment procedures (normal & emergency)
- Emergency runbook with step-by-step procedures
- Success criteria checklist

**Why First:** This is the blueprint for everything else. Once designed, implementation becomes straightforward.

---

### TASK 2: Consolidate Directory Structure
**Priority:** HIGH
**Effort:** 2-3 hours
**Status:** Ready to execute

**Changes:**
- Move `/aws` directory into `/k8s/aws`
- Create `/k8s/debian` module structure
- Prepare `/k8s/kubernetes` as module
- Create root `/k8s/main.tf` for orchestration

**Result:** Single `tofu apply` from k8s/ deploys everything

---

### TASK 3: Implement FRP Emergency Access Logic
**Priority:** HIGH
**Effort:** 3-4 hours
**Status:** Ready to code

**Changes:**
- Create `k8s/aws/frp.tf` - FRP enable/disable toggle
- Create `k8s/debian/main.tf` - WireGuard config + FRP client
- Create `k8s/debian/variables.tf` - Configuration parameters
- Update root `k8s/main.tf` - Module orchestration with health check

**Key Logic:**
```
tofu apply
  ↓
[Health Check: Can we reach Debian?]
  ├─ YES → FRP disabled, normal deployment
  └─ NO → FRP auto-enabled for emergency access
```

**Critical Fix:** VPN IP: 10.99.0.2 → 10.99.0.20 (via Terraform)

---

### TASK 4: Add Audit Logging & Documentation
**Priority:** MEDIUM
**Effort:** 1-2 hours
**Status:** Ready to implement

**Deliverables:**
- `k8s/DEPLOYMENT_LOG.md` - Track all deployments
- `k8s/AUDIT_TRAIL.md` - Change history table
- Git commits with clear messages

**Documentation Fixes:**
- Remove false claim: "Secured all GCS keys" (move to Phase 2A)
- Add Phase 2A section: "Key Cleanup + Google Secret Manager"

---

## 📅 Execution Timeline

### Week 1 (CRITICAL PATH)

**Day 1-2: Planning & Directory Merge**
- [ ] Design Debian deployment plan (TASK 1)
- [ ] Review design with stakeholders
- [ ] Merge AWS into k8s/ structure (TASK 2)

**Day 3-4: Implementation**
- [ ] Implement FRP emergency access logic (TASK 3)
- [ ] Add audit logging (TASK 4)
- [ ] Test: `tofu plan` (no errors)
- [ ] Deploy: `tofu apply`

**Day 5: Deployment & Apps**
- [ ] Verify Debian accessibility (normal or emergency)
- [ ] Deploy MLflow to Kubernetes
- [ ] Deploy niivue app to Kubernetes
- [ ] Verify three core priorities are met

**Estimated Total:** 9-13 hours

---

### Week 2+ (PHASE 2A - Advanced Hardening)

**Once Phase 1 Complete:**
- OIDC + RBAC: 3 hours
- Pod Security: 2 hours
- Network Policies: 2 hours
- Traefik Hardening: 2 hours
- **Total: 9 hours**

---

## 🔑 Key Implementation Details

### Directory Structure Target
```
k8s/
├── aws/                          [Module: Bastion + WireGuard + FRP]
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── frp.tf                   [NEW: Emergency access]
│   └── wireguard-peers.auto.tfvars.json
├── debian/                       [Module: VPN Peer + FRP Client]
│   ├── main.tf                  [NEW: Config + WireGuard fix]
│   └── variables.tf             [NEW: Parameters]
├── kubernetes/                   [Module: K8s Cluster]
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── main.tf                       [NEW: Root orchestrator]
├── variables.tf                  [NEW: Aggregated config]
├── outputs.tf                    [NEW: Deployment outputs]
├── DEBIAN_DEPLOYMENT_PLAN.md    [Design doc]
├── DEPLOYMENT_LOG.md            [Deployment tracking]
└── AUDIT_TRAIL.md               [Change history]
```

### Terraform Dependencies
```
aws_bastion (deploys first)
    ↓
debian_host (depends on bastion outputs)
    ↓
kubernetes_cluster (depends on debian completion)
```

### Health Check Logic
```hcl
variable "enable_frp_emergency" {
  description = "Auto-enable when Debian check fails"
  type        = bool
  default     = false  # Will be set to true if health check fails
}

# FRP security group rule only created if enabled
resource "aws_security_group_rule" "frp_port" {
  count = var.enable_frp_emergency ? 1 : 0
  # Opens FRP port (7000) for emergency access
}
```

---

## ✅ Success Criteria

### Each Task
1. **TASK 1:** Design document complete, reviewed, and approved
2. **TASK 2:** All files copied, directory structure correct
3. **TASK 3:** Code compiles with `tofu validate`, logic tested
4. **TASK 4:** Audit documents created, false claims removed

### Overall (End of Week)
- [ ] `tofu apply` from k8s/ deploys entire infrastructure
- [ ] Debian accessible via WireGuard (normal) or FRP (emergency)
- [ ] Kubernetes cluster operational with all hardening active
- [ ] MLflow deployed and working
- [ ] niivue app deployed to K8s
- [ ] GKE can be decommissioned
- [ ] Audit trail in place
- [ ] Phase 1 ready to sign off

---

## 🚀 How to Execute

### Prerequisites
1. Review MEETING_SUMMARY.md for context
2. Understand architecture in DEBIAN_DEPLOYMENT_PLAN.md
3. Have Terraform/OpenTofu installed
4. Have required AWS credentials configured

### Step-by-Step

**1. Create Design Document (2-3h)**
```
- Create k8s/DEBIAN_DEPLOYMENT_PLAN.md
- Document architecture
- Review and get approval
```

**2. Prepare Infrastructure (2-3h)**
```bash
cd project_root
mkdir -p k8s/aws k8s/debian
# Copy AWS files to k8s/aws/
# Create Debian module structure
```

**3. Implement Code (3-4h)**
```bash
cd k8s
# Create aws/frp.tf
# Create debian/main.tf
# Create debian/variables.tf
# Update main.tf
# Update variables.tf
# Update outputs.tf
```

**4. Test (1h)**
```bash
cd k8s
tofu init
tofu validate
tofu plan  # Review output
```

**5. Deploy (1-2h)**
```bash
tofu apply
# Monitor output
# Verify resources created
```

**6. Verify (1h)**
```bash
# Test Debian accessibility
# Test Kubernetes cluster
# Verify hardening features
```

---

## 📊 Resource Requirements

### Infrastructure
- AWS account with:
  - EC2 access
  - Security group creation capability
  - Elastic IP allocation
- Debian host (pre-existing or create via Terraform)

### Configuration Needed
- AWS region, VPC, subnet IDs
- SSH key pair name
- Debian host IP address
- WireGuard keys (public/private)
- FRP token/password

### Tools
- OpenTofu (or Terraform)
- kubectl (for K8s verification)
- ssh (for testing connections)
- git (for version control)

---

## ⚠️ Critical Points

1. **Everything via Code**
   - No manual VPN configuration
   - No manual FRP toggles
   - All changes in Git

2. **Both Team Members Must Understand**
   - No automation of unclear processes
   - Document decisions
   - Test procedures manually first

3. **Emergency Procedures**
   - FRP is safety mechanism only
   - Should be disabled when not needed
   - Document procedures for team knowledge

4. **Three Priorities**
   - MLflow working
   - niivue app deployed
   - GKE shutdown (cost savings)

---

## 📝 Documentation Standards

### Terraform Code Comments
- Explain WHY not just WHAT
- Document module inputs/outputs
- Include examples in comments

### Procedures
- Step-by-step instructions
- Expected outputs for verification
- Troubleshooting steps

### Commits
- Clear messages
- Reference tasks
- Explain changes

---

## 🔄 Phase 2 (After Phase 1 Complete)

### Phase 2A: Advanced Hardening
Once Phase 1 is signed off, proceed with:
- OIDC + RBAC (3h)
- Network Policies (2h)
- Traefik Hardening (2h)
- Pod Security (2h - potentially complex)

### Phase 2B: Credential Rotation
- Implement Google Secret Manager integration
- External Secrets Operator for K8s sync
- Automated rotation (30-90 day schedule)

### Phase 2C: Advanced Automation
- Compliance dashboards
- Automated remediation
- Advanced monitoring

---

## 💬 Communication

**Daily Status:**
- Share progress on blocked items
- Report successes and issues
- Adjust timeline if needed

**Decision Points:**
- Design review before implementation
- Plan review before execution
- Post-deployment verification

**Escalation:**
- Immediate escalation if blocked
- Quick feedback loops
- Collaborative problem-solving

---

**Status:** Ready to Execute
**Next Action:** Start TASK 1 (design document)
**Owner:** Development Team
**Collaboration:** Stakeholder review at key points

