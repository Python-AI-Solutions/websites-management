# Cloud Security Audit  
_AWS jump host · WireGuard VPN · Single-node Kubernetes · Cloudflare_

---

## 1. Executive Summary

You’re already doing several important things right:

- Heavy use of **IaC (Terraform/OpenTofu)** for AWS, Cloudflare, and k8s.
- A **dedicated k8s machine** behind a **WireGuard VPN**.
- Cloudflare fronting public web traffic (DNS, Pages, WAF potential).
- Very small trusted admin set (**you and Sumit**).

Given your explicit assumption that **laptops may be compromised**, the main goal is to **minimize blast radius** and **remove public entry points** wherever possible.

### Most urgent fixes (do these first)

1. **Close the public door to Kubernetes API & NodePorts.**  
   - Lock **6443** and **30000–32767** to the WireGuard subnet only, or close entirely.

2. **Stop exporting cluster-admin kubeconfig to laptops.**  
   - Don’t copy `/etc/kubernetes/admin.conf` to local machines as a long-lived credential.
   - Move to **OIDC + RBAC** and short-lived, least-privilege kubeconfigs.

3. **Kill or heavily restrict public SSH.**  
   - Restrict SSH to the WireGuard subnet and/or move the AWS jump host to **SSM Session Manager**.

4. **Enable etcd secret encryption + API audit logging.**  
   - Encrypt Kubernetes Secrets at rest.
   - Turn on kube-apiserver audit logging for forensics.

5. **Move k8s Terraform to remote, locked state.**  
   - Use S3+DynamoDB (or GCS) with versioning and locking instead of local state.

### Strategic direction (strongly recommended)

- Terminate **all external HTTP/S** through **Cloudflare Tunnel**, not directly on the k8s node.
- Use **Cloudflare mTLS / Authenticated Origin Pulls** so only Cloudflare can reach your ingress.
- Centralize identity (SSO + hardware keys) and use **short-lived OIDC/OAuth credentials** for AWS, Cloudflare, and k8s.
- Implement **two-person control** for sensitive operations (Terraform apply to prod, high-risk k8s changes).

---

## 2. Repo & Architecture: What’s There

From the `compute-setup` structure, the key pieces are:

### 2.1 Cloudflare IaC

- OpenTofu/Terraform modules for:
  - **Cloudflare zone + DNS records**.
  - **Cloudflare Pages** (static sites).
  - **Google Workspace email** (MX, SPF, DKIM, DMARC).
- Good practices:
  - Modules for Cloudflare with `proxied` defaults for A/CNAME records.
  - Linting and pre-commit hooks (`tflint`, etc.).

### 2.2 AWS Jump Host

- Single **EC2 instance** acting as a “cloud interface” / bastion:
  - Security Group allows:
    - `jump_host_ssh_cidrs` (defaults to `["0.0.0.0/0"]`) on port **22**.
    - Application ports like **7005** from configurable CIDRs.
    - **WireGuard UDP 51820**.
- Used to:
  - Host WireGuard server.
  - Provide SSH access to internal resources / k8s host.

### 2.3 WireGuard VPN

- Terraform variables for:
  - `wireguard_port` (51820).
  - Peer configuration in a `wireguard-peers.auto.tfvars.json` file (public keys only).
- Goal:
  - All sensitive admin traffic should flow through WireGuard.

### 2.4 Kubernetes Host

- Single node (control-plane + worker) provisioned via Terraform (`k8s/main.tf`):
  - Installs **containerd** and **kubeadm/kubelet/kubectl**.
  - Initializes a **single control plane** with kubeadm.
  - Installs:
    - **Cilium** (CNI & NetworkPolicy).
    - **Traefik** (Ingress).
    - **cert-manager** (TLS automation).
- Firewall (iptables) setup:
  - Default `DROP` on INPUT/FORWARD; ACCEPT on OUTPUT.
  - Allows:
    - `lo`, established/related.
    - SSH (22).
    - WireGuard (51820/udp).
    - Kubernetes API (6443).
    - NodePorts (30000–32767).
    - HTTP/HTTPS (80/443).
  - Currently, many of these are open **to the world** by default.

- Kubeconfig handling:
  - `/etc/kubernetes/admin.conf` is copied off the node and `chmod 644`, which is dangerous if laptops are compromised.

- State:
  - k8s Terraform currently uses **local state** (remote backend scaffolding exists but isn’t active).

---

## 3. Top 10 Security Improvements (Concrete)

### 3.1 Restrict Kubernetes API (6443) to VPN Only

**Problem:**  
Kubernetes API is reachable from the internet. If discovered, it’s a prime target.

**Goal:**  
Only WireGuard clients (e.g., `10.99.0.0/24`) can talk to `6443`.

**Actions:**

1. **Remove any “open to world” rules** for `6443` in iptables and Terraform (`exposed_ports` variable).
2. **Add a source-restricted rule** for WG subnet:

```bash
# Allow k8s API only from WireGuard subnet
sudo iptables -A INPUT -p tcp --dport 6443   -s 10.99.0.0/24   -m comment --comment 'K8s API via WG'   -j ACCEPT
```

3. Ensure `6443` is **not** included in any generic “open to all” port list.

---

### 3.2 Block NodePorts from the Internet

**Problem:**  
NodePort range (30000–32767) is exposed publicly, which is a huge attack surface.

**Goal:**  
No direct NodePort exposure to the internet.

**Actions:**

1. Remove these rules:

```bash
sudo iptables -D INPUT -p tcp --dport 30000:32767 -m comment --comment 'K8s NodePort services' -j ACCEPT
sudo iptables -D INPUT -p udp --dport 30000:32767 -m comment --comment 'K8s NodePort services' -j ACCEPT
```

2. If you truly need NodePorts from VPN, add WG-subnet-only rules:

```bash
sudo iptables -A INPUT -p tcp --dport 30000:32767   -s 10.99.0.0/24   -m comment --comment 'NodePort from WG'   -j ACCEPT

sudo iptables -A INPUT -p udp --dport 30000:32767   -s 10.99.0.0/24   -m comment --comment 'NodePort from WG'   -j ACCEPT
```

3. Prefer **ClusterIP + Ingress** instead of NodePorts for apps.

---

### 3.3 Use Cloudflare Tunnel; Close Origin 80/443

**Problem:**  
Origin node currently exposes HTTP/HTTPS publicly, making it an internet-facing attack surface.

**Goal:**  
Terminate all public traffic at Cloudflare; the k8s node should have no internet-exposed web ports.

**Actions:**

- Deploy `cloudflared` as a Deployment/DaemonSet in the cluster and create Cloudflare Tunnels that route to Traefik services.
- Configure DNS in Cloudflare to point records at the tunnel, not directly at the origin IP.
- Close ports **80** and **443** to the public on the k8s node.
- Optionally, allow 80/443 only from:
  - Cloudflare IP ranges, **or**
  - Exclusively over the tunnel (preferred) with no direct inbound access.
- Enable **Authenticated Origin Pulls** or full **mTLS** between Cloudflare and Traefik so only Cloudflare can reach the ingress endpoints.

Result: No inbound ports open to the internet on the origin; all traffic reaches k8s via Cloudflare’s outgoing tunnel.

---

### 3.4 Remove Public SSH; Use SSM and WireGuard

**Problem:**  
Public SSH access (0.0.0.0/0 to port 22) is a high-value target for brute force and credential attacks.

**Goal:**  
No public SSH; all admin access via WireGuard or SSM.

**Actions (AWS jump host):**

- Attach an IAM role that allows **SSM Session Manager**.
- Use `aws ssm start-session` instead of SSH for routine admin tasks.
- Set `jump_host_ssh_cidrs = []` or a very narrow corporate egress range.
- Eventually, close port 22 altogether in the Security Group.

**Actions (k8s host):**

- Remove port 22 from any “open to world” lists.
- Only allow SSH from the WireGuard subnet `10.99.0.0/24` via iptables.
- Prefer **SSH certificates** (with a small internal CA like `step-ca`) instead of static SSH keys.

---

### 3.5 Stop Exporting Admin Kubeconfig; Use OIDC + RBAC

**Problem:**  
`admin.conf` gives full cluster control. If your laptop is compromised, attacker gets total control.

**Goal:**  
No long-lived, full-privilege kubeconfig on laptops.

**Actions:**

- Remove the provisioning step that copies `/etc/kubernetes/admin.conf` to any local machine.
- If you must fetch it in an emergency:
  - Use it once.
  - Set `0600` permissions.
  - Delete it immediately after use.
- Deploy an **OIDC provider** (Dex, Pinniped, or direct IdP integration) and map SSO groups to Kubernetes roles.
- Create roles for:
  - **Viewer/Read-only**.
  - **Deployer/Operator** (namespace-scoped).
  - **Cluster-admin (break-glass)** with manual approval and very limited use.
- Make kubeconfigs **short-lived** and tied to SSO sessions with MFA + hardware keys.

---

### 3.6 Enable Etcd Secret Encryption + API Audit Logging

**Problem:**  
By default, Kubernetes stores Secrets unencrypted in etcd, and you have no detailed audit trail of sensitive API calls.

**Goal:**  
Encrypt secrets at rest; log important API activity for forensics.

**Actions:**

1. **Etcd Secret Encryption** (kubeadm-based cluster):
   - Create `/etc/kubernetes/encryption-config.yaml` on the control-plane node:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <32-byte-base64-key>
      - identity: {}
```

   - Patch the kube-apiserver manifest or kubeadm config to include:

```text
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

   - Restart kube-apiserver and re-encrypt secrets when rotating keys.

2. **API Audit Logging**:
   - Create `/etc/kubernetes/audit-policy.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    verbs: ["create","update","patch","delete","deletecollection","impersonate"]
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets","configmaps"]
      - group: "apps"
        resources: ["deployments","statefulsets","daemonsets"]
    verbs: ["create","update","patch","delete"]
```

   - Add to kube-apiserver args:

```text
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=7
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

   - Ship audit logs to your log aggregator (e.g., Loki).

---

### 3.7 Enforce Pod Security, Seccomp, and NetworkPolicies

**Problem:**  
Without pod-level hardening and network segmentation, any compromised workload can move laterally easily.

**Goal:**  
Make each workload as constrained and isolated as possible.

**Actions:**

- **Pod Security Admission / Kyverno**:
  - Enforce `restricted` level in all namespaces (or equivalent Kyverno policies).
  - Example namespace labels:

```bash
kubectl label ns <your-namespace>   pod-security.kubernetes.io/enforce=restricted   pod-security.kubernetes.io/audit=restricted   pod-security.kubernetes.io/warn=restricted
```

- **SecurityContext defaults**:
  - Use `seccompProfile: RuntimeDefault`.
  - Drop capabilities (`NET_RAW`, etc.) by default.
  - Avoid privileged pods; use hostPath and hostNetwork sparingly.

- **NetworkPolicies with Cilium**:
  - Create namespace-wide **default deny** policies.
  - Define per-app allowlists for ingress and egress.

Example default deny:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: <your-namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

---

### 3.8 Harden Traefik (Ingress)

**Problem:**  
Ingress is the main external-facing interface; misconfig there is critical.

**Goal:**  
Traefik only accepts traffic from Cloudflare (preferably via tunnel), with strong TLS and optional mTLS for sensitive endpoints.

**Actions:**

- Terminate TLS with **modern ciphers and TLS 1.2+**.
- Redirect HTTP → HTTPS where needed; or disable HTTP completely once ACME challenges are no longer required.
- Restrict sensitive routes (dashboards, admin APIs) with:
  - mTLS, and/or
  - IP allowlists (e.g., WG subnet only), and/or
  - Auth middleware (OIDC, basic auth, etc.).
- Do not expose Traefik dashboard publicly.

---

### 3.9 Harden CI/CD & Supply Chain

**Problem:**  
If your CI or image pipeline is compromised, attackers can deploy malicious containers “legitimately”.

**Goal:**  
Ensure only verified, scanned images and IaC changes make it to production.

**Actions:**

- **GitHub security**:
  - Enforce branch protection with reviews and **CODEOWNERS** (you + Sumit for critical paths).
  - Require **signed commits** for protected branches.
  - Use **GitHub OIDC** to issue short-lived cloud credentials instead of long-lived keys.

- **Container supply chain**:
  - Generate **SBOMs** (e.g., Syft) and scan images (Trivy/Grype).
  - **Sign images with Cosign** and enforce verification in-cluster (Kyverno `verifyImages`).
  - Pin deployments to image **digests** (no `:latest`).

- **Terraform workflow**:
  - Keep `plan` and `apply` behind GitHub Actions or an equivalent pipeline.
  - Require manual approval (two-person rule) for production applies.

---

### 3.10 Move to Remote, Locked Terraform State + Backups

**Problem:**  
Local state is fragile, easier to lose or corrupt, and harder to audit.

**Goal:**  
Remote, versioned, locked Terraform state and regular backups for cluster data.

**Actions:**

- For k8s Terraform:
  - Use remote backend (S3+DynamoDB or GCS) with:
    - Bucket versioning.
    - Server-side encryption.
    - DynamoDB table for state locking.
- For the cluster itself:
  - Schedule regular **etcd snapshots**.
  - Store backups in an **immutable** storage class (e.g., S3 Object Lock).
  - Practice full cluster restore in a lab environment.

---

## 4. Concrete Patches & Snippets

### 4.1 Tighten k8s iptables (Example)

```bash
# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Loopback and established
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# WireGuard
sudo iptables -A INPUT -p udp --dport 51820 -m comment --comment 'WireGuard' -j ACCEPT
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT

# Allow SSH **only** from WireGuard
sudo iptables -A INPUT -p tcp --dport 22   -s 10.99.0.0/24   -m comment --comment 'SSH via WG'   -j ACCEPT

# Allow k8s API **only** from WireGuard
sudo iptables -A INPUT -p tcp --dport 6443   -s 10.99.0.0/24   -m comment --comment 'K8s API via WG'   -j ACCEPT

# (Optional) NodePorts from WG only, if you really need them
sudo iptables -A INPUT -p tcp --dport 30000:32767   -s 10.99.0.0/24   -m comment --comment 'NodePort via WG'   -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30000:32767   -s 10.99.0.0/24   -m comment --comment 'NodePort via WG'   -j ACCEPT

# Save
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
```

---

### 4.2 Etcd Secret Encryption (Recap)

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <32-byte-base64-key>
      - identity: {}
```

kube-apiserver arg:

```text
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

---

### 4.3 API Audit Policy (Recap)

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    verbs: ["create","update","patch","delete","deletecollection","impersonate"]
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets","configmaps"]
      - group: "apps"
        resources: ["deployments","statefulsets","daemonsets"]
    verbs: ["create","update","patch","delete"]
```

kube-apiserver args:

```text
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=7
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

---

### 4.4 Pod Security Baseline Labels

```bash
kubectl label ns <your-namespace>   pod-security.kubernetes.io/enforce=restricted   pod-security.kubernetes.io/audit=restricted   pod-security.kubernetes.io/warn=restricted
```

---

### 4.5 Default Deny NetworkPolicy (Recap)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: <your-namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

---

## 5. Identity, Devices, and Two-Person Rule

- **SSO everywhere**: Use Google Workspace (or similar) as your IdP.
- **MFA + hardware keys** for both you and Sumit.
- **Short-lived access**:
  - AWS via IAM Identity Center or OIDC from GitHub Actions.
  - Cloudflare via scoped API tokens, rotated regularly.
  - Kubernetes via OIDC with expiring tokens.

- **Two-person control**:
  - Protected branches with required reviews.
  - GitHub Environments for production with mandatory approvers.
  - A documented **break-glass** process for cluster-admin or root-level access.

---

## 6. Cloudflare Hardening Checklist

- Use **Cloudflare Tunnel** for all dynamic apps instead of exposing origin 80/443.
- Enable **Authenticated Origin Pulls** or full **mTLS** to Traefik.
- Ensure DNS for public sites is always **proxied** (orange cloud).
- Turn on **WAF** and **rate limiting** rules for API endpoints and login pages.
- Enforce **HSTS** and modern TLS settings on the edge.
- Enable **Logpush** to send HTTP/WAF logs to your log sink for analysis.

---

## 7. AWS Jump Host Hardening

- Prefer **SSM Session Manager** over SSH.
- Remove 0.0.0.0/0 from SSH SG rules; eventually, close SSH entirely.
- Keep the instance minimal:
  - Minimal packages installed.
  - Automatic security updates.
  - IMDSv2 enforced.
- Restrict IAM role permissions to **only** what WireGuard and needed utilities require.

---

## 8. Operations, Monitoring, and Recovery

- **Backups**:
  - Regular etcd snapshots.
  - App-level backups (databases, object storage) with versioning and immutability.

- **Monitoring & Detection**:
  - Integrate cluster logs (kube-apiserver, audit, kubelet, container logs) into a central system.
  - Use Falco / Tetragon or similar to detect suspicious container behavior.
  - Monitor Cloudflare WAF events and unusual traffic patterns.

- **Runbooks**:
  - Access revocation and credential rotation procedures.
  - Incident response checklist (triage, containment, eradication, recovery, post-mortem).
  - Disaster recovery steps (rebuild cluster from IaC + restore backups).

---

## 9. Phased Implementation Plan

### Next 48 Hours

- Lock down k8s API and NodePorts to WireGuard.
- Restrict SSH to WG/SSM; stop exporting `admin.conf`.
- Enable etcd encryption and API audit logging.

### Next 2 Weeks

- Deploy Cloudflare Tunnel and close origin 80/443 to the internet.
- Set up OIDC for k8s and start using least-privilege roles.
- Apply default-deny NetworkPolicies and Pod Security restricted policies.
- Move k8s Terraform to remote, locked state.

### This Quarter

- Migrate AWS jump host fully to SSM, no public SSH.
- Introduce signed container images and policy enforcement.
- Centralize logs from Cloudflare and k8s with alerting.
- Finalize two-person approval flows and break-glass procedures.

---

If you’d like to iterate further, we can turn this into a checklist linked directly to specific Terraform and k8s manifests (e.g., “PR-ready” changes for `k8s/main.tf`, Cloudflare configs, and the AWS module).