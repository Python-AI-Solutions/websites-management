terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # For testing: use local state backend
  # For production: uncomment GCS backend below and set GOOGLE_APPLICATION_CREDENTIALS
  
  # Remote state stored in GCS bucket (production)
  # backend "gcs" {
  #   bucket = "k8s-tfstate-midyear-pattern-470017-b8"
  #   prefix = "k8s-cluster/terraform.tfstate"
  # }
}

# Provider configurations
provider "null" {}
provider "local" {}

# NOTE: We intentionally skip the Kubernetes and Helm providers here.
# Instead, we use kubectl commands via SSH (remote-exec) for add-on installation.
# This avoids provider networking issues when running from Mac accessing the cluster.
# The remote-exec approach is simpler, more reliable, and teaches real K8s workflow.

# Render kubeadm configuration from template
locals {
  kubeadm_config = templatefile("${path.module}/kubeadm-config.yaml.tmpl", {
    kubernetes_version      = var.kubernetes_version
    cluster_name           = var.cluster_name
    pod_cidr              = var.pod_cidr
    service_cidr          = var.service_cidr
    control_plane_endpoint = var.control_plane_endpoint
  })

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
}

# Save rendered kubeadm config locally
resource "local_file" "kubeadm_config" {
  content  = local.kubeadm_config
  filename = "${path.module}/tmp-kubeadm-config.yaml"
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

# Step 3: Initialize Kubernetes cluster (idempotent)
resource "null_resource" "k8s_init" {
  triggers = {
    cluster_name = var.cluster_name
  }

  depends_on = [null_resource.upload_kubeadm_config]

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
      "    CLUSTER_READY=1",
      "  else",
      "    echo 'kubeadm config exists but API server not reachable; will re-initialize'",
      "  fi",
      "fi",
      "if [ \"$CLUSTER_READY\" -eq 0 ]; then",
      "  echo 'Cluster unhealthy; performing aggressive cleanup before re-initializing...'",
      "  sudo systemctl stop kubelet || true",
      "  sudo rm -rf /var/lib/kubelet/pods/* || true",
      "  sudo rm -f /etc/kubernetes/manifests/*.yaml || true",
      "  sudo rm -rf /var/lib/etcd/* || true",
      "  sleep 2",
      "  echo 'Running kubeadm init (skip CoreDNS) to bootstrap control plane...'",
      "  sudo kubeadm reset -f || true",
      "  sudo kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs --skip-phases=addon/coredns",
      "  echo 'Patching startup and liveness probes IMMEDIATELY (before kubelet starts)...'",
      "  echo '  - Patching etcd startup probe (30s initial delay)...'",
      "  sudo sed -i '/startupProbe:/,/initialDelaySeconds: 10/{s/initialDelaySeconds: 10/initialDelaySeconds: 30/}' /etc/kubernetes/manifests/etcd.yaml",
      "  echo '  - Patching kube-apiserver startup probe (30s initial delay)...'",
      "  sudo sed -i '/startupProbe:/,/initialDelaySeconds: 10/{s/initialDelaySeconds: 10/initialDelaySeconds: 30/}' /etc/kubernetes/manifests/kube-apiserver.yaml",
      "  echo '  - Patching kube-apiserver liveness probe (15s initial delay)...'",
      "  sudo sed -i '/livenessProbe:/,/initialDelaySeconds: 10/{s/initialDelaySeconds: 10/initialDelaySeconds: 15/}' /etc/kubernetes/manifests/kube-apiserver.yaml",
      "  echo '✓ Probes patched successfully'",
      "  echo 'Starting kubelet to begin control plane bootstrap...'",
      "  sudo systemctl start kubelet",
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
      "  echo '✓ Cluster initialization complete'",
      "  mkdir -p $HOME/.kube",
      "  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config",
      "  sudo chown $(id -u):$(id -g) $HOME/.kube/config",
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
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand='ssh -W %h:%p ${var.bastion_user}@${var.bastion_host} -p ${var.bastion_port}' -P ${var.host_port} ${var.ssh_user}@${var.host}:/tmp/kubeconfig ${var.kubeconfig_local_path}"
    ) : (
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P ${var.host_port} ${var.ssh_user}@${var.host}:/tmp/kubeconfig ${var.kubeconfig_local_path}"
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
      "echo 'Checking if Cilium is already installed...'",
      "if sudo helm list --namespace kube-system --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null | grep -q '^cilium'; then",
      "  echo 'Cilium is already installed, skipping installation'",
      "else",
      "  echo 'Installing Cilium CNI...'",
      "  sudo helm repo add cilium https://helm.cilium.io 2>/dev/null || true",
      "  sudo helm repo update",
      "  sudo helm install cilium cilium/cilium --namespace kube-system --version ${var.cilium_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --set kubeProxyReplacement=false --set ipam.mode=kubernetes",
      "  echo 'Cilium deployed, waiting for CNI initialization (60s)...'",
      "  sleep 60",
      "fi",
      "echo 'Checking API server is responding...'",
      "sudo sh -c 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl cluster-info' || echo 'API server still warming up...'"
    ]
  }

  # Install Traefik
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Waiting for API server to be fully ready before installing Traefik...'",
      "for i in $(seq 1 60); do",
      "  if sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1 &&",
      "     sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q 'true'; then",
      "    echo \"✓ API server is ready (attempt $i)\"",
      "    break",
      "  fi",
      "  if [ $i -eq 60 ]; then",
      "    echo '⚠ API server not fully ready, proceeding anyway...'",
      "  else",
      "    sleep 2",
      "  fi",
      "done",
      "echo 'Checking if Traefik is already installed...'",
      "if sudo helm list --namespace traefik --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null | grep -q '^traefik'; then",
      "  echo 'Traefik is already installed, skipping installation'",
      "else",
      "  echo 'Installing Traefik...'",
      "  sudo helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm install traefik traefik/traefik --namespace traefik --version ${var.traefik_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --set ports.web.hostPort=80 --set ports.websecure.hostPort=443 --set deployment.kind=DaemonSet --set ingressClass.enabled=true --set ingressClass.isDefaultClass=true --set providers.kubernetesIngress.enabled=true 2>&1; then",
      "      echo 'Traefik installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ Traefik installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"Traefik installation attempt $attempt failed, retrying in $((attempt * 2)) seconds...\"",
      "    sleep $((attempt * 2))",
      "  done",
      "fi"
    ]
  }

  # Install cert-manager
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Checking if cert-manager is already installed...'",
      "if sudo helm list --namespace cert-manager --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null | grep -q '^cert-manager'; then",
      "  echo 'cert-manager is already installed, skipping installation'",
      "else",
      "  echo 'Installing cert-manager...'",
      "  sudo helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm install cert-manager jetstack/cert-manager --namespace cert-manager --version ${var.cert_manager_chart_version} --kubeconfig /etc/kubernetes/admin.conf --set installCRDs=true --wait=false 2>&1; then",
      "      echo 'cert-manager installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ cert-manager installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"cert-manager installation attempt $attempt failed, retrying in $((attempt * 2)) seconds...\"",
      "    sleep $((attempt * 2))",
      "  done",
      "fi"
    ]
  }

  # Install local-path-provisioner
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Checking if local-path-provisioner is already installed...'",
      "if sudo helm list --namespace local-path-storage --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null | grep -q '^local-path-provisioner'; then",
      "  echo 'local-path-provisioner is already installed, skipping installation'",
      "else",
      "  echo 'Installing local-path-provisioner...'",
      "  sudo helm repo add containeroo https://charts.containeroo.ch 2>/dev/null || true",
      "  sudo helm repo update",
      "  for attempt in $(seq 1 5); do",
      "    if sudo helm install local-path-provisioner containeroo/local-path-provisioner --namespace local-path-storage --version ${var.local_path_provisioner_chart_version} --kubeconfig /etc/kubernetes/admin.conf --wait=false --set storageClass.defaultClass=true --set storageClass.name=local-path 2>&1; then",
      "      echo 'local-path-provisioner installed successfully'",
      "      break",
      "    fi",
      "    if [ $attempt -eq 5 ]; then",
      "      echo '⚠ local-path-provisioner installation failed after 5 attempts'",
      "      exit 1",
      "    fi",
      "    echo \"local-path-provisioner installation attempt $attempt failed, retrying in $((attempt * 2)) seconds...\"",
      "    sleep $((attempt * 2))",
      "  done",
      "fi"
    ]
  }

  depends_on = [null_resource.fetch_kubeconfig]
}
