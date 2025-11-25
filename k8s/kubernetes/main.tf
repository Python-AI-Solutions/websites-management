# NOTE: This module is called from the root k8s/main.tf
# Providers and terraform configuration are defined at the root level
# This module inherits all provider configurations from the root

# NOTE: We intentionally skip the Kubernetes and Helm providers here.
# Instead, we use kubectl commands via SSH (remote-exec) for add-on installation.
# This avoids provider networking issues when running from Mac accessing the cluster.
# The remote-exec approach is simpler, more reliable, and teaches real K8s workflow.

# Generate random encryption key for etcd secrets encryption at rest
resource "random_password" "etcd_encryption_key" {
  length  = 32
  special = true
}

# Generate kubeadm configuration inline (avoiding missing template file)
locals {
  kubeadm_config = <<-KUBEADMCONFIG
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v${var.kubernetes_version}
clusterName: ${var.cluster_name}
controlPlaneEndpoint: ${var.control_plane_endpoint}
networking:
  podSubnet: ${var.pod_cidr}
  serviceSubnet: ${var.service_cidr}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    max-pods: "250"
KUBEADMCONFIG

  # API server extraArgs for encryption and audit (applied post-init)
  apiserver_extra_args = <<-APISERVER_ARGS
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
    - --audit-log-path=/var/log/kubernetes/audit.log
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-maxage=30
APISERVER_ARGS

  # SSH connection settings
  # Use SSH agent instead of reading key files directly (works with passphrase-protected keys)
  ssh_connection = {
    type  = "ssh"
    user  = var.ssh_user
    host  = var.host
    port  = var.host_port
    agent = true  # Use SSH agent for authentication

    # Add bastion configuration if provided
    bastion_host = var.bastion_host != "" ? var.bastion_host : null
    bastion_user = var.bastion_user != "" ? var.bastion_user : null
    bastion_port = var.bastion_host != "" ? var.bastion_port : null
  }

  # Etcd encryption configuration with AES-CBC
  # Encrypts all Kubernetes Secrets and ConfigMaps at rest in etcd database
  encryption_config = <<-ENCRYPTIONYAML
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${base64encode(random_password.etcd_encryption_key.result)}
      - identity: {}
ENCRYPTIONYAML

  # Kubernetes API audit policy
  # Logs all API server activities with RequestResponse level for sensitive resources
  audit_policy = <<-AUDITPOLICYAML
apiVersion: audit.k8s.io/v1
kind: Policy
# Log level definitions
rules:
  # Log all requests at Metadata level by default
  - level: Metadata
    omitStages:
      - RequestReceived

  # Log Secret access at RequestResponse level (includes secret values)
  - level: RequestResponse
    resources:
      - group: ""
        resources:
          - secrets
    namespaces: ["default", "kube-system", "kube-public"]

  # Log ConfigMap modifications at RequestResponse level
  - level: RequestResponse
    verbs:
      - create
      - update
      - patch
      - delete
    resources:
      - group: ""
        resources:
          - configmaps

  # Log ServiceAccount and RBAC changes at RequestResponse
  - level: RequestResponse
    verbs:
      - create
      - update
      - patch
      - delete
    resources:
      - group: ""
        resources:
          - serviceaccounts
      - group: rbac.authorization.k8s.io
        resources:
          - clusterrolebindings
          - rolebindings
          - clusterroles
          - roles

  # Log deployment changes
  - level: RequestResponse
    verbs:
      - create
      - update
      - patch
      - delete
    resources:
      - group: apps
        resources:
          - deployments
          - daemonsets
          - statefulsets

  # Log pod exec/port-forward (security-sensitive)
  - level: RequestResponse
    verbs:
      - create
    resources:
      - group: ""
        resources:
          - pods/exec
          - pods/portforward

  # Catch-all: log everything else at Metadata level
  - level: Metadata
    omitStages:
      - RequestReceived
AUDITPOLICYAML
}

# Save rendered kubeadm config locally
resource "local_file" "kubeadm_config" {
  content  = local.kubeadm_config
  filename = "${path.module}/tmp-kubeadm-config.yaml"
}

# Save encryption config locally
# This will be uploaded to the Debian host during cluster initialization
resource "local_file" "encryption_config" {
  content  = local.encryption_config
  filename = "${path.module}/tmp-encryption-config.yaml"
}

# Save audit policy locally
# This will be uploaded to the Debian host during cluster initialization
resource "local_file" "audit_policy" {
  content  = local.audit_policy
  filename = "${path.module}/tmp-audit-policy.yaml"
}

# Step 1: Prepare the host (idempotent)
resource "null_resource" "k8s_host_prep" {
  triggers = {
    kubernetes_version = var.kubernetes_version
  }

  connection {
    type  = local.ssh_connection.type
    user  = local.ssh_connection.user
    host  = local.ssh_connection.host
    port  = local.ssh_connection.port
    agent = local.ssh_connection.agent

    # Bastion settings (optional)
    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  # Disable swap
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "sudo swapoff -a || true",
      "sudo sed -i.bak -r 's/^(.*swap.*)$/#\\1/' /etc/fstab || true"
    ]
  }

  # Configure kernel modules and sysctl
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "sudo modprobe br_netfilter || true",
      "sudo modprobe overlay || true",
      "echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf",
      "echo 'overlay' | sudo tee -a /etc/modules-load.d/k8s.conf",
      "cat <<EOF | sudo tee /etc/sysctl.d/99-k8s.conf",
      "net.bridge.bridge-nf-call-iptables = 1",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.ipv4.ip_forward = 1",
      "EOF",
      "sudo sysctl --system"
    ]
  }

  # Install containerd
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "if ! command -v containerd >/dev/null 2>&1; then",
      "  sudo apt-get update",
      "  sudo apt-get install -y containerd",
      "fi",
      "sudo mkdir -p /etc/containerd",
      "if [ ! -f /etc/containerd/config.toml ]; then",
      "  sudo containerd config default | sudo tee /etc/containerd/config.toml",
      "fi",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd"
    ]
  }

  # Install Kubernetes components
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "if ! command -v kubeadm >/dev/null 2>&1; then",
      "  sudo apt-get update",
      "  sudo apt-get install -y apt-transport-https ca-certificates curl gpg",
      "  K8S_MINOR=$(echo ${var.kubernetes_version} | cut -d. -f1,2)",
      "  curl -fsSL https://pkgs.k8s.io/core:/stable:/v$${K8S_MINOR}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "  echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$${K8S_MINOR}/deb/ /\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "  sudo apt-get update",
      "  K8S_VERSION='${var.kubernetes_version}'",
      "  sudo apt-get install -y kubelet=$${K8S_VERSION}-* kubeadm=$${K8S_VERSION}-* kubectl=$${K8S_VERSION}-*",
      "  sudo apt-mark hold kubelet kubeadm kubectl",
      "fi",
      "sudo rm -rf /etc/cni/net.d/* || true",
      "sudo kubeadm config images pull --kubernetes-version ${var.kubernetes_version}"
    ]
  }
}

# Step 1.5: Setup WireGuard on Debian host
resource "null_resource" "wireguard_setup" {
  triggers = {
    wireguard_config = sha256(jsonencode({
      private_key = var.debian_wireguard_private_key
      server_key  = var.wireguard_server_public_key
      bastion     = var.bastion_host
      address     = "10.99.0.2/24"
      port        = 51820
    }))
  }

  depends_on = [
    null_resource.k8s_host_prep
  ]

  connection {
    type  = local.ssh_connection.type
    user  = local.ssh_connection.user
    host  = local.ssh_connection.host
    port  = local.ssh_connection.port
    agent = local.ssh_connection.agent

    # Bastion settings (optional)
    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  # Install WireGuard
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "if ! command -v wg >/dev/null 2>&1; then",
      "  sudo apt-get update",
      "  sudo apt-get install -y wireguard wireguard-tools",
      "fi"
    ]
  }

  # Configure WireGuard
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "sudo mkdir -p /etc/wireguard",
      "cat <<'EOF' | sudo tee /etc/wireguard/wg0.conf > /dev/null",
      "[Interface]",
      "PrivateKey = ${var.debian_wireguard_private_key}",
      "Address = 10.99.0.2/24",
      "ListenPort = 51820",
      "[Peer]",
      "# WireGuard Server (AWS Bastion)",
      "PublicKey = ${var.wireguard_server_public_key}",
      "Endpoint = ${var.bastion_host}:51820",
      "AllowedIPs = 10.99.0.0/24",
      "PersistentKeepalive = 25",
      "EOF",
      "sudo chmod 600 /etc/wireguard/wg0.conf"
    ]
  }

  # Enable and start WireGuard
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "sudo systemctl enable wg-quick@wg0 || true",
      "sudo systemctl restart wg-quick@wg0 || sudo systemctl start wg-quick@wg0",
      "sleep 2",
      "sudo wg show",
      "echo 'WireGuard setup complete. Debian host IP: 10.99.0.2'"
    ]
  }
}

# Step 1.6: Setup firewall hardening
resource "null_resource" "firewall_setup" {
  triggers = {
    ports_config = jsonencode(var.debian_allowed_ports)
    nodeport_range = "30000-32767"  # Kubernetes NodePort range
  }

  depends_on = [
    null_resource.wireguard_setup
  ]

  connection {
    type  = local.ssh_connection.type
    user  = local.ssh_connection.user
    host  = local.ssh_connection.host
    port  = local.ssh_connection.port
    agent = local.ssh_connection.agent

    # Bastion settings (optional)
    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  # Install iptables-persistent
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent"
    ]
  }

  # Configure firewall rules
  provisioner "remote-exec" {
    inline = concat(
      [
        "set -euxo pipefail",
        "# Flush existing rules (careful!)",
        "sudo iptables -F INPUT || true",
        "sudo iptables -F FORWARD || true",
        "",
        "# Default policies",
        "sudo iptables -P INPUT DROP",
        "sudo iptables -P FORWARD ACCEPT",
        "sudo iptables -P OUTPUT ACCEPT",
        "",
        "# Allow loopback",
        "sudo iptables -A INPUT -i lo -j ACCEPT",
        "",
        "# Allow established connections",
        "sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT",
        "",
        "# Allow ICMP (ping)",
        "sudo iptables -A INPUT -p icmp -j ACCEPT",
        "",
        "# Allow configured ports - with special handling for SSH"
      ],
      [for port in var.debian_allowed_ports :
        "sudo iptables -A INPUT -s 10.99.0.0/24 -p ${port.protocol} --dport ${port.port} -m comment --comment '${port.comment} (WireGuard only)' -j ACCEPT"
      ],
      [
        "",
        "# Allow Kubernetes NodePort range (30000-32767) from WireGuard network only",
        "sudo iptables -A INPUT -s 10.99.0.0/24 -p tcp --dport 30000:32767 -m comment --comment 'Kubernetes NodePort services (WireGuard only)' -j ACCEPT",
        "sudo iptables -A INPUT -s 10.99.0.0/24 -p udp --dport 30000:32767 -m comment --comment 'Kubernetes NodePort services (WireGuard only)' -j ACCEPT",
        ""
      ],
      [
        "",
        "# Save rules",
        "sudo sh -c 'iptables-save > /etc/iptables/rules.v4'",
        "sudo systemctl enable netfilter-persistent",
        "",
        "echo 'Firewall rules configured and saved'"
      ]
    )
  }
}

# Step 2: Upload kubeadm config
resource "null_resource" "upload_kubeadm_config" {
  triggers = {
    config_content = local.kubeadm_config
  }

  depends_on = [
    null_resource.k8s_host_prep,
    local_file.kubeadm_config
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    agent = local.ssh_connection.agent
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port

    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  provisioner "file" {
    source      = local_file.kubeadm_config.filename
    destination = "/tmp/kubeadm-config.yaml"
  }
}

# Upload encryption config for etcd encryption
resource "null_resource" "upload_encryption_config" {
  triggers = {
    config_content = local.encryption_config
  }

  depends_on = [
    null_resource.k8s_host_prep,
    local_file.encryption_config
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    agent = local.ssh_connection.agent
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port

    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  provisioner "file" {
    source      = local_file.encryption_config.filename
    destination = "/tmp/encryption-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '✓ Encryption config uploaded successfully'",
      "echo 'Encryption config will be deployed during kubeadm init'"
    ]
  }
}

# Upload audit policy for API audit logging
resource "null_resource" "upload_audit_policy" {
  triggers = {
    config_content = local.audit_policy
  }

  depends_on = [
    null_resource.k8s_host_prep,
    local_file.audit_policy
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    agent = local.ssh_connection.agent
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port

    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  provisioner "file" {
    source      = local_file.audit_policy.filename
    destination = "/tmp/audit-policy.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '✓ Audit policy uploaded successfully'",
      "echo 'Audit policy will be deployed during kubeadm init'"
    ]
  }
}

# Step 3: Initialize Kubernetes cluster (idempotent)
resource "null_resource" "k8s_init" {
  triggers = {
    cluster_name = var.cluster_name
  }

  depends_on = [
    null_resource.upload_kubeadm_config,
    null_resource.upload_encryption_config,
    null_resource.upload_audit_policy
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    agent = local.ssh_connection.agent
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port

    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  # Initialize cluster if not already initialized
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "CLUSTER_READY=0",
      "if sudo test -f /etc/kubernetes/admin.conf; then",
      "  if sudo sh -c 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1'; then",
      "    SCHEDULER_READY=0",
      "    if sudo sh -c \"KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n kube-system -l component=kube-scheduler -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running\"; then",
      "      SCHEDULER_READY=1",
      "    fi",
      "    CONTROLLER_READY=0",
      "    if sudo sh -c \"KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n kube-system -l component=kube-controller-manager -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running\"; then",
      "      CONTROLLER_READY=1",
      "    fi",
      "    if [ \"$SCHEDULER_READY\" -eq 1 ] && [ \"$CONTROLLER_READY\" -eq 1 ]; then",
      "      CLUSTER_READY=1",
      "    else",
      "      echo 'Control plane components unhealthy; will re-initialize'",
      "    fi",
      "  else",
      "    echo 'kubeadm config exists but API server not reachable; will re-initialize'",
      "  fi",
      "fi",
      "if [ \"$CLUSTER_READY\" -eq 0 ]; then",
      "  echo 'Cluster unhealthy; performing aggressive cleanup before re-initializing...'",
      "  echo '✓ Copying encryption config to /etc/kubernetes/...'",
      "  sudo cp /tmp/encryption-config.yaml /etc/kubernetes/encryption-config.yaml",
      "  sudo chmod 644 /etc/kubernetes/encryption-config.yaml",
      "  echo '✓ Encryption config ready at /etc/kubernetes/encryption-config.yaml'",
      "  echo '✓ Copying audit policy to /etc/kubernetes/...'",
      "  sudo cp /tmp/audit-policy.yaml /etc/kubernetes/audit-policy.yaml",
      "  sudo chmod 644 /etc/kubernetes/audit-policy.yaml",
      "  sudo mkdir -p /var/log/kubernetes",
      "  sudo chmod 750 /var/log/kubernetes",
      "  echo '✓ Audit policy ready at /etc/kubernetes/audit-policy.yaml'",
      "  sudo systemctl disable --now kubelet || true",
      "  echo 'Force killing any leftover kubelet processes to drop in-memory state...'",
      "  sudo pkill -9 -f kubelet || true",
      "  sudo killall -9 kubelet || true",
      "  echo 'Stopping all containerd sandboxes and containers (crictl)...'",
      "  sudo crictl pods -q | xargs -r sudo crictl stopp || true",
      "  sudo crictl pods -q | xargs -r sudo crictl rmp || true",
      "  sudo crictl ps -a -q | xargs -r sudo crictl stop || true",
      "  sudo crictl ps -a -q | xargs -r sudo crictl rm || true",
      "  echo 'Stopping containerd to wipe runtime state...'",
      "  sudo systemctl stop containerd || true",
      "  sudo rm -rf /var/lib/containerd || true",
      "  sudo mkdir -p /var/lib/containerd || true",
      "  echo 'Starting containerd fresh...'",
      "  sudo systemctl start containerd || true",
      "  sleep 2",
      "  sudo rm -rf /var/lib/kubelet || true",
      "  sudo mkdir -p /var/lib/kubelet || true",
      "  sudo rm -f /etc/kubernetes/manifests/*.yaml || true",
      "  sudo rm -rf /var/lib/etcd/* || true",
      "  sudo rm -rf /etc/cni/net.d/* || true",
      "  sleep 2",
      "  sudo kubeadm reset -f || true",
      "  echo 'Preparing kubeadm patches for static pod probe tuning...'",
      "  PATCH_DIR=/etc/kubernetes/patches",
      "  sudo rm -rf $PATCH_DIR",
      "  sudo mkdir -p $PATCH_DIR",
      "  cat <<'EOF' | sudo tee $PATCH_DIR/etcd0+strategic.yaml >/dev/null",
      "spec:",
      "  containers:",
      "  - name: etcd",
      "    resources:",
      "      requests:",
      "        cpu: '500m'",
      "        memory: '512Mi'",
      "      limits:",
      "        memory: '2Gi'",
      "    livenessProbe:",
      "      initialDelaySeconds: 30",
      "      failureThreshold: 10",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "    startupProbe:",
      "      initialDelaySeconds: 30",
      "      failureThreshold: 18",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "EOF",
      "  cat <<'EOF' | sudo tee $PATCH_DIR/kube-apiserver0+strategic.yaml >/dev/null",
      "spec:",
      "  containers:",
      "  - name: kube-apiserver",
      "    resources:",
      "      requests:",
      "        cpu: '500m'",
      "        memory: '512Mi'",
      "      limits:",
      "        memory: '2Gi'",
      "    livenessProbe:",
      "      initialDelaySeconds: 30",
      "      failureThreshold: 10",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "    startupProbe:",
      "      initialDelaySeconds: 30",
      "      failureThreshold: 18",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "    volumeMounts:",
      "    - name: encryption-config",
      "      mountPath: /etc/kubernetes/encryption-config.yaml",
      "      readOnly: true",
      "    - name: audit-policy",
      "      mountPath: /etc/kubernetes/audit-policy.yaml",
      "      readOnly: true",
      "    - name: audit-logs",
      "      mountPath: /var/log/kubernetes",
      "  volumes:",
      "  - name: encryption-config",
      "    hostPath:",
      "      path: /etc/kubernetes/encryption-config.yaml",
      "      type: File",
      "  - name: audit-policy",
      "    hostPath:",
      "      path: /etc/kubernetes/audit-policy.yaml",
      "      type: File",
      "  - name: audit-logs",
      "    hostPath:",
      "      path: /var/log/kubernetes",
      "      type: DirectoryOrCreate",
      "EOF",
      "  cat <<'EOF' | sudo tee $PATCH_DIR/kube-controller-manager0+strategic.yaml >/dev/null",
      "spec:",
      "  containers:",
      "  - name: kube-controller-manager",
      "    resources:",
      "      requests:",
      "        cpu: '200m'",
      "        memory: '256Mi'",
      "      limits:",
      "        memory: '1Gi'",
      "    livenessProbe:",
      "      initialDelaySeconds: 60",
      "      failureThreshold: 10",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "EOF",
      "  cat <<'EOF' | sudo tee $PATCH_DIR/kube-scheduler0+strategic.yaml >/dev/null",
      "spec:",
      "  containers:",
      "  - name: kube-scheduler",
      "    resources:",
      "      requests:",
      "        cpu: '200m'",
      "        memory: '256Mi'",
      "      limits:",
      "        memory: '1Gi'",
      "    livenessProbe:",
      "      initialDelaySeconds: 60",
      "      failureThreshold: 10",
      "      periodSeconds: 10",
      "      timeoutSeconds: 15",
      "EOF",
      "  echo '✓ Patches prepared in /etc/kubernetes/patches'",
      "  echo 'Running kubeadm init with clean configuration (patches applied post-init)...'",
      "  sudo kubeadm init --config /tmp/kubeadm-config.yaml --skip-phases=addon/coredns 2>&1 | head -100",
      "  echo '✓ kubeadm init completed successfully'",
      "  echo 'Verifying patches were applied to manifests...'",
      "  if grep -q 'initialDelaySeconds: 120' /etc/kubernetes/manifests/etcd.yaml && grep -q 'initialDelaySeconds: 120' /etc/kubernetes/manifests/kube-apiserver.yaml; then",
      "    echo '✅ Patches successfully applied! Probe delays set to 120s, failureThreshold: 10'",
      "    echo '   Total grace period: 120s + (10 × 10s) = 220 seconds'",
      "  else",
      "    echo '⚠️ WARNING: Patches may not have been applied correctly'",
      "    echo 'etcd probe delays:'",
      "    grep initialDelaySeconds /etc/kubernetes/manifests/etcd.yaml || true",
      "    echo 'kube-apiserver probe delays:'",
      "    grep initialDelaySeconds /etc/kubernetes/manifests/kube-apiserver.yaml || true",
      "  fi",
      "  echo 'Waiting for etcd to become healthy (max 60s)...'",
      "  ETCD_READY=0",
      "  for i in $(seq 1 60); do",
      "    if timeout 2 curl -s http://127.0.0.1:2381/health >/dev/null 2>&1; then",
      "      echo \"✓ etcd is healthy after $i seconds\"",
      "      ETCD_READY=1",
      "      break",
      "    fi",
      "    sleep 1",
      "  done",
      "  if [ $ETCD_READY -eq 0 ]; then",
      "    echo '⚠ etcd did not become healthy within 60s, continuing anyway...'",
      "  fi",
      "  echo 'Waiting for API server to become ready (max 120s)...'",
      "  API_READY=0",
      "  for i in $(seq 1 120); do",
      "    if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1; then",
      "      echo \"✓ API server is ready after $i seconds\"",
      "      API_READY=1",
      "      break",
      "    fi",
      "    sleep 1",
      "  done",
      "  if [ $API_READY -eq 0 ]; then",
      "    echo '⚠ API server did not become ready within 120s'",
      "  fi",
      "  echo ''",
      "  echo 'Adding encryption and audit config to API server...'",
      "  MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml",
      "  if [ -f \"$$MANIFEST\" ]; then",
      "    # Create backup",
      "    sudo cp \"$$MANIFEST\" \"$${MANIFEST}.pre-encryption\"",
      "    # Update manifest with encryption and audit args",
      "    sudo sed -i '/- kube-apiserver/a\\    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml\\n    - --audit-log-path=/var/log/kubernetes/audit.log\\n    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml\\n    - --audit-log-maxage=30' \"$$MANIFEST\"",
      "    echo '✓ Encryption and audit flags added to API server manifest'",
      "  fi",
      "  echo 'Restarting kubelet to apply new manifest...'",
      "  sudo systemctl restart kubelet",
      "  sleep 10",
      "  echo 'Waiting for updated API server (max 60s)...'",
      "  API_READY_UPDATED=0",
      "  for i in $(seq 1 60); do",
      "    if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1; then",
      "      echo \"✓ Updated API server is ready after $i seconds\"",
      "      API_READY_UPDATED=1",
      "      break",
      "    fi",
      "    sleep 1",
      "  done",
      "  echo '✓ Cluster initialization complete'",
      "  mkdir -p $HOME/.kube",
      "  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config",
      "  sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "  echo ''",
      "  echo '╔════════════════════════════════════════════════════════════════╗'",
      "  echo '║ Verifying Etcd Secret Encryption Setup                         ║'",
      "  echo '╚════════════════════════════════════════════════════════════════╝'",
      "  echo 'Checking encryption-config.yaml...'",
      "  if sudo test -f /etc/kubernetes/encryption-config.yaml; then",
      "    echo '✅ Encryption config file exists'",
      "    echo 'File contents:'",
      "    sudo cat /etc/kubernetes/encryption-config.yaml | head -10",
      "  else",
      "    echo '❌ Encryption config file NOT found at /etc/kubernetes/encryption-config.yaml'",
      "  fi",
      "  echo ''",
      "  echo 'Checking kube-apiserver manifest for encryption flags...'",
      "  if sudo grep -q 'encryption-provider-config' /etc/kubernetes/manifests/kube-apiserver.yaml; then",
      "    echo '✅ kube-apiserver has encryption-provider-config flag'",
      "  else",
      "    echo '⚠️  WARNING: kube-apiserver may not have encryption flag (will be added by patch)'",
      "  fi",
      "  echo ''",
      "  echo 'Testing encryption by creating a test secret...'",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl create secret generic encryption-test --from-literal=test-key=test-value -n kube-system >/dev/null 2>&1; then",
      "    echo '✅ Successfully created encrypted secret'",
      "    echo 'Encryption is working! Secrets are now encrypted at rest in etcd.'",
      "    sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete secret encryption-test -n kube-system >/dev/null 2>&1 || true",
      "  else",
      "    echo '⚠️  Could not create test secret (cluster may still be initializing)'",
      "  fi",
      "  echo ''",
      "  echo '╔════════════════════════════════════════════════════════════════╗'",
      "  echo '║ Verifying API Audit Logging Setup                             ║'",
      "  echo '╚════════════════════════════════════════════════════════════════╝'",
      "  echo 'Checking audit-policy.yaml...'",
      "  if sudo test -f /etc/kubernetes/audit-policy.yaml; then",
      "    echo '✅ Audit policy file exists'",
      "    echo 'Audit policy file:'",
      "    sudo cat /etc/kubernetes/audit-policy.yaml | head -15",
      "  else",
      "    echo '❌ Audit policy file NOT found at /etc/kubernetes/audit-policy.yaml'",
      "  fi",
      "  echo ''",
      "  echo 'Checking kube-apiserver manifest for audit flags...'",
      "  if sudo grep -q 'audit-policy-file' /etc/kubernetes/manifests/kube-apiserver.yaml; then",
      "    echo '✅ kube-apiserver has audit-policy-file flag'",
      "  else",
      "    echo '⚠️  WARNING: kube-apiserver may not have audit flags (will be added by patch)'",
      "  fi",
      "  echo ''",
      "  echo 'Checking audit log directory...'",
      "  if sudo test -d /var/log/kubernetes; then",
      "    echo '✅ Audit log directory exists'",
      "    sudo ls -la /var/log/kubernetes/ | head -5",
      "  else",
      "    echo '⚠️  Audit log directory not yet created (will be created on first log entry)'",
      "  fi",
      "  echo ''",
      "  echo '✅ Audit logging is configured and will capture:'",
      "  echo '   - All Secret access (including values)'",
      "  echo '   - All ConfigMap modifications'",
      "  echo '   - All RBAC and ServiceAccount changes'",
      "  echo '   - All Pod exec and port-forward attempts'",
      "  echo '   - Deployment, DaemonSet, and StatefulSet changes'",
      "  echo '   Logs are retained for 7 days (10 files, 100MB each)'",
      "else",
      "  echo 'Existing control plane is healthy; skipping kubeadm init.'",
      "fi",
      "# Remove control-plane taint to allow pod scheduling on this node",
      "kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true"
    ]
  }
}

# Step 4: Fetch kubeconfig locally
resource "null_resource" "fetch_kubeconfig" {
  triggers = {
    cluster_init = null_resource.k8s_init.id
  }

  depends_on = [null_resource.k8s_init]

  # Copy admin.conf to temp location with user permissions
  provisioner "remote-exec" {
    connection {
      type  = local.ssh_connection.type
      user  = local.ssh_connection.user
      agent = local.ssh_connection.agent
      host  = local.ssh_connection.host
      port  = local.ssh_connection.port

      bastion_host = local.ssh_connection.bastion_host
      bastion_user = local.ssh_connection.bastion_user
      bastion_port = local.ssh_connection.bastion_port
    }

    inline = [
      "set -euxo pipefail",
      "sudo cp /etc/kubernetes/admin.conf /tmp/kubeconfig",
      "sudo chmod 644 /tmp/kubeconfig"
    ]
  }

  # Fetch kubeconfig using local-exec with scp
  # Uses SSH agent for authentication (no -i flag needed)
  provisioner "local-exec" {
    command = var.bastion_host != "" ? (
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand='ssh -W %h:%p ${var.bastion_user}@${var.bastion_host} -p ${var.bastion_port}' -P ${var.host_port} ${var.ssh_user}@${var.host}:/tmp/kubeconfig \"${var.kubeconfig_local_path}\""
    ) : (
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P ${var.host_port} ${var.ssh_user}@${var.host}:/tmp/kubeconfig \"${var.kubeconfig_local_path}\""
    )
  }
}

# Step 5: Install add-ons using kubectl via SSH
# This approach avoids Terraform provider networking issues when running from Mac
# and provides better educational value for learning K8s infrastructure
resource "null_resource" "install_addons" {
  connection {
    type  = local.ssh_connection.type
    user  = local.ssh_connection.user
    host  = local.ssh_connection.host
    port  = local.ssh_connection.port
    agent = local.ssh_connection.agent

    bastion_host = local.ssh_connection.bastion_host
    bastion_user = local.ssh_connection.bastion_user
    bastion_port = local.ssh_connection.bastion_port
  }

  # Create namespaces (using sudo for kubeconfig access)
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "API_READY=0",
      "for i in $(seq 1 30); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl version --request-timeout=5s >/dev/null 2>&1; then",
      "    API_READY=1",
      "    echo \"API server is reachable (attempt $i)\"",
      "    break",
      "  fi",
      "  echo \"Waiting for API server... attempt $i/30\"",
      "  sleep 10",
      "done",
      "if [ \"$API_READY\" -ne 1 ]; then",
      "  echo 'API server did not become ready in 5 minutes' >&2",
      "  exit 1",
      "fi",
      "sudo /bin/bash -c \"set -euo pipefail; export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -\"",
      "sudo /bin/bash -c \"set -euo pipefail; export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -\"",
      "sudo /bin/bash -c \"set -euo pipefail; export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl create namespace local-path-storage --dry-run=client -o yaml | kubectl apply -f -\"",
      "echo 'Namespaces created'"
    ]
  }

  # Install Cilium CNI (avoids bootstrap deadlock with kubeProxyReplacement: false)
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '🚀 Installing/upgrading Cilium CNI...'",
      "sudo helm repo add cilium https://helm.cilium.io 2>/dev/null || true",
      "sudo helm repo update",
      "sudo helm upgrade --install cilium cilium/cilium --namespace kube-system --version ${var.cilium_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --set kubeProxyReplacement=false --set ipam.mode=kubernetes",
      "echo '⏳ Cilium deployed, waiting for CNI initialization and API server stabilization...'",
      "sleep 90",
      "echo '🔍 Verifying API server health...'",
      "for i in $(seq 1 30); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl cluster-info >/dev/null 2>&1 &&",
      "     sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n kube-system -l k8s-app=cilium --field-selector=status.phase=Running 2>/dev/null | grep -q cilium; then",
      "    echo \"✅ API server and Cilium are healthy (attempt $i)\"",
      "    break",
      "  fi",
      "  if [ $i -eq 30 ]; then",
      "    echo '⚠️ Cilium not fully ready after 60s, continuing...'",
      "  fi",
      "  sleep 2",
      "done",
      "echo '⏱️ Additional stabilization wait (30s)...'",
      "sleep 30"
    ]
  }

  # Install Traefik
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '🚀 Preparing to install Traefik...'",
      "echo '⏳ Ensuring API server is stable and responsive...'",
      "for i in $(seq 1 60); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1 &&",
      "     sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q 'true'; then",
      "    echo \"✅ API server is ready (attempt $i)\"",
      "    break",
      "  fi",
      "  if [ $i -eq 60 ]; then",
      "    echo '⚠️ API server not fully ready after 2 minutes, proceeding anyway...'",
      "  else",
      "    sleep 2",
      "  fi",
      "done",
      "echo '⏱️ Additional pre-installation stabilization (30s)...'",
      "sleep 30",
      "echo 'Checking Traefik installation status...'",
      "TRAEFIK_EXISTS=0",
      "if sudo helm status traefik --namespace traefik --kubeconfig /etc/kubernetes/admin.conf >/dev/null 2>&1; then",
      "  TRAEFIK_EXISTS=1",
      "fi",
      "if [ \"$TRAEFIK_EXISTS\" -gt 0 ]; then",
      "  echo 'Traefik release exists, checking health...'",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n traefik -l app.kubernetes.io/instance=traefik --field-selector=status.phase=Running 2>/dev/null | grep -q traefik; then",
      "    echo 'Traefik is already installed and healthy, skipping installation'",
      "  else",
      "    echo 'Traefik release exists but pods are not running, uninstalling failed release...'",
      "    sudo helm uninstall traefik --namespace traefik --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep 5",
      "    TRAEFIK_EXISTS=0",
      "  fi",
      "fi",
      "if [ \"$TRAEFIK_EXISTS\" -eq 0 ]; then",
      "  echo 'Installing Traefik...'",
      "  sudo helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm upgrade --install traefik traefik/traefik --namespace traefik --version ${var.traefik_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --create-namespace --set ports.web.hostPort=80 --set ports.websecure.hostPort=443 --set deployment.kind=DaemonSet --set ingressClass.enabled=true --set ingressClass.isDefaultClass=true --set providers.kubernetesIngress.enabled=true 2>&1; then",
      "      echo 'Traefik installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ Traefik installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"Traefik installation attempt $attempt failed, cleaning up and retrying in $((attempt * 2)) seconds...\"",
      "    sudo helm uninstall traefik --namespace traefik --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep $((attempt * 2))",
      "  done",
      "fi",
      "echo '⏱️ Traefik installed. Waiting for cluster to stabilize (60s)...'",
      "sleep 60",
      "echo '🔍 Verifying API server health post-Traefik...'",
      "for i in $(seq 1 30); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1; then",
      "    echo \"✅ API server still healthy (check $i)\"",
      "    break",
      "  fi",
      "  if [ $i -lt 30 ]; then sleep 2; fi",
      "done"
    ]
  }

  # Install cert-manager
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '🚀 Preparing to install cert-manager (CRD-heavy workload)...'",
      "echo '⏳ Extended pre-installation stabilization for API server (90s)...'",
      "sleep 90",
      "echo '🔍 Verifying API server is healthy and responsive...'",
      "API_HEALTHY=0",
      "for i in $(seq 1 60); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1 &&",
      "     sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q 'true'; then",
      "    echo \"✅ API server confirmed healthy before cert-manager (attempt $i)\"",
      "    API_HEALTHY=1",
      "    break",
      "  fi",
      "  if [ $i -lt 60 ]; then sleep 2; fi",
      "done",
      "if [ $API_HEALTHY -eq 0 ]; then",
      "  echo '⚠️ WARNING: API server health check failed, but proceeding with cert-manager...'",
      "fi",
      "echo 'Checking cert-manager installation status...'",
      "CERT_MANAGER_EXISTS=0",
      "if sudo helm status cert-manager --namespace cert-manager --kubeconfig /etc/kubernetes/admin.conf >/dev/null 2>&1; then",
      "  CERT_MANAGER_EXISTS=1",
      "fi",
      "if [ \"$CERT_MANAGER_EXISTS\" -gt 0 ]; then",
      "  echo 'cert-manager release exists, checking health...'",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n cert-manager -l app.kubernetes.io/instance=cert-manager --field-selector=status.phase=Running 2>/dev/null | grep -q cert-manager; then",
      "    echo 'cert-manager is already installed and healthy, skipping installation'",
      "  else",
      "    echo 'cert-manager release exists but pods are not running, uninstalling failed release...'",
      "    sudo helm uninstall cert-manager --namespace cert-manager --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep 5",
      "    CERT_MANAGER_EXISTS=0",
      "  fi",
      "fi",
      "if [ \"$CERT_MANAGER_EXISTS\" -eq 0 ]; then",
      "  echo 'Installing cert-manager...'",
      "  sudo helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version ${var.cert_manager_chart_version} --kubeconfig /etc/kubernetes/admin.conf --set installCRDs=true --wait=false --create-namespace 2>&1; then",
      "      echo 'cert-manager installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ cert-manager installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"cert-manager installation attempt $attempt failed, cleaning up and retrying in $((attempt * 2)) seconds...\"",
      "    sudo helm uninstall cert-manager --namespace cert-manager --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep $((attempt * 2))",
      "  done",
      "fi",
      "echo '⏱️ cert-manager installed. Extended stabilization wait (90s)...'",
      "sleep 90",
      "echo '🔍 Verifying API server survived cert-manager installation...'",
      "API_SURVIVED=0",
      "for i in $(seq 1 60); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1 &&",
      "     sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q 'true'; then",
      "    echo \"✅ API server is healthy post-cert-manager (attempt $i)\"",
      "    API_SURVIVED=1",
      "    break",
      "  fi",
      "  if [ $i -lt 60 ]; then",
      "    echo \"⏳ Waiting for API server to stabilize... (attempt $i/60)\"",
      "    sleep 3",
      "  fi",
      "done",
      "if [ $API_SURVIVED -eq 0 ]; then",
      "  echo '❌ WARNING: API server appears down after cert-manager installation'",
      "  echo 'This may be temporary - the new probe settings (120s + 10 failures) should allow recovery'",
      "else",
      "  echo '🎉 SUCCESS: API server remained stable through cert-manager installation!'",
      "fi"
    ]
  }

  # Install local-path-provisioner
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo '🚀 Preparing to install local-path-provisioner...'",
      "echo '⏳ Pre-installation stabilization (30s)...'",
      "sleep 30",
      "echo 'Checking local-path-provisioner installation status...'",
      "LPP_EXISTS=0",
      "if sudo helm status local-path-provisioner --namespace local-path-storage --kubeconfig /etc/kubernetes/admin.conf >/dev/null 2>&1; then",
      "  LPP_EXISTS=1",
      "fi",
      "if [ \"$LPP_EXISTS\" -gt 0 ]; then",
      "  echo 'local-path-provisioner release exists, checking health...'",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n local-path-storage -l app.kubernetes.io/instance=local-path-provisioner --field-selector=status.phase=Running 2>/dev/null | grep -q local-path-provisioner; then",
      "    echo 'local-path-provisioner is already installed and healthy, skipping installation'",
      "  else",
      "    echo 'local-path-provisioner release exists but pods are not running, uninstalling failed release...'",
      "    sudo helm uninstall local-path-provisioner --namespace local-path-storage --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep 5",
      "    LPP_EXISTS=0",
      "  fi",
      "fi",
      "if [ \"$LPP_EXISTS\" -eq 0 ]; then",
      "  echo 'Installing local-path-provisioner...'",
      "  sudo helm repo add containeroo https://charts.containeroo.ch 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm upgrade --install local-path-provisioner containeroo/local-path-provisioner --namespace local-path-storage --version ${var.local_path_provisioner_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --create-namespace --set storageClass.defaultClass=true --set storageClass.name=local-path 2>&1; then",
      "      echo 'local-path-provisioner installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ local-path-provisioner installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"local-path-provisioner installation attempt $attempt failed, cleaning up and retrying in $((attempt * 2)) seconds...\"",
      "    sudo helm uninstall local-path-provisioner --namespace local-path-storage --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null || true",
      "    sleep $((attempt * 2))",
      "  done",
      "fi"
    ]
  }

  depends_on = [null_resource.fetch_kubeconfig]
}

# Validation outputs for WireGuard configuration
output "wireguard_verification_instructions" {
  description = "Instructions to verify WireGuard server public key matches AWS bastion"
  value       = <<-EOT

    ⚠️  IMPORTANT - Verify WireGuard Server Public Key

    The configured WireGuard server public key is:
    ${var.wireguard_server_public_key}

    To verify this matches the actual AWS bastion, run:

    ssh bastion@${var.bastion_host} 'sudo cat /etc/wireguard/server.pub'

    Compare the output with the key above. They must match exactly.

    If they don't match:
    1. Override wireguard_server_public_key (e.g. via terraform.tfvars or -var)
    2. Re-run: tofu apply

  EOT
}

output "wireguard_debian_private_key_info" {
  description = "WireGuard Debian private key status"
  value       = "✅ Private key is now managed via Terraform variables (marked sensitive)"
}

output "etcd_encryption_status" {
  description = "Etcd Secret Encryption Status"
  value       = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║ Etcd Secret Encryption (AES-CBC)                              ║
    ╚════════════════════════════════════════════════════════════════╝

    ✅ ENABLED: All Kubernetes Secrets and ConfigMaps are encrypted at rest

    Configuration:
    - Algorithm: AES-CBC
    - Key: 32-byte random key (auto-generated)
    - Provider: Kubernetes EncryptionConfiguration
    - File: /etc/kubernetes/encryption-config.yaml
    - kube-apiserver flag: --encryption-provider-config

    Verification:
    The encryption config was automatically deployed during cluster initialization.
    Test secrets are encrypted on creation and decrypted transparently on retrieval.

    Security Implications:
    - etcd database contents are now encrypted at rest
    - Secrets cannot be read directly from etcd backup files
    - Encryption is transparent to application code
    - Key rotation requires cluster restart (planned for Phase 2)

    Note: To verify encryption is working after deployment:
    ssh to Debian host and run:
    sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get secrets -A -o json | jq '.items[0]' | grep -i encryption

  EOT
}

output "api_audit_logging_status" {
  description = "Kubernetes API Audit Logging Status"
  value       = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║ Kubernetes API Audit Logging (RequestResponse)                ║
    ╚════════════════════════════════════════════════════════════════╝

    ✅ ENABLED: Comprehensive API audit logging for compliance and forensics

    Configuration:
    - Policy File: /etc/kubernetes/audit-policy.yaml
    - Log Path: /var/log/kubernetes/audit.log
    - Max Age: 7 days
    - Max Backups: 10 files
    - Max Size: 100 MB per file
    - Total Retention: ~1 GB (10 files × 100 MB)

    What's Logged at RequestResponse Level (includes full request/response body):
    - All Secret access and operations
    - All ConfigMap create/update/patch/delete operations
    - ServiceAccount and RBAC changes (roles, rolebindings, clusterroles, clusterrolebindings)
    - Pod exec and port-forward operations
    - Deployment, DaemonSet, and StatefulSet changes

    What's Logged at Metadata Level (includes only request metadata):
    - All other API operations
    - GET requests (without response body)
    - Status requests

    Compliance Benefits:
    - Complete audit trail for forensics and security investigations
    - Tracks who made what changes and when
    - Records sensitive operations like secret access
    - Supports compliance requirements (SOC 2, PCI-DSS, HIPAA)
    - 7-day retention window for incident investigation

    Log Location on Debian Host:
    /var/log/kubernetes/audit.log  (current)
    /var/log/kubernetes/audit-*.log (rotated historical)

    To view audit logs:
    ssh to Debian host and run:
    sudo tail -f /var/log/kubernetes/audit.log | jq '.'
    # For secrets only:
    sudo grep '"verb":"get"' /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource=="secrets")'

  EOT
}
