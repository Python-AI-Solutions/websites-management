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
      "  echo 'Running kubeadm init to bootstrap control plane...'",
      "  sudo kubeadm reset -f || true",
      "  echo 'Phase 1: Initialize etcd first, wait for it to be ready'",
      "  sudo kubeadm init phase etcd --config /tmp/kubeadm-config.yaml",
      "  echo 'Waiting 5 seconds for etcd to stabilize...'",
      "  sleep 5",
      "  echo 'Phase 2: Initialize API server and other control plane components'",
      "  sudo kubeadm init phase control-plane --config /tmp/kubeadm-config.yaml --upload-certs",
      "  echo 'Phase 3: Generate bootstraptoken'",
      "  sudo kubeadm init phase bootstrap-token --config /tmp/kubeadm-config.yaml",
      "  echo 'Cluster initialization complete via staged phases'",
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
      "sudo sh -c 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -'",
      "sudo sh -c 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -'",
      "sudo sh -c 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl create namespace local-path-storage --dry-run=client -o yaml | kubectl apply -f -'",
      "echo 'Namespaces created'"
    ]
  }

  # Install Cilium CNI (avoids bootstrap deadlock with kubeProxyReplacement: false)
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Installing Cilium CNI...'",
      "sudo helm repo add cilium https://helm.cilium.io 2>/dev/null || true",
      "sudo helm repo update",
      "export KUBECONFIG=/etc/kubernetes/admin.conf && sudo helm install cilium cilium/cilium --namespace kube-system --version ${var.cilium_chart_version} --wait=false --values - <<EOF",
      "kubeProxyReplacement: false",
      "ipam:",
      "  mode: kubernetes",
      "EOF",
      "echo 'Cilium deployed, waiting for CNI initialization (60s)...'",
      "sleep 60",
      "echo 'Checking API server is responding...'",
      "sudo sh -c 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl cluster-info' || echo 'API server still warming up...'"
    ]
  }

  # Install Traefik
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Installing Traefik...'",
      "sudo helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true",
      "sudo helm repo update",
      "export KUBECONFIG=/etc/kubernetes/admin.conf && sudo helm install traefik traefik/traefik --namespace traefik --version ${var.traefik_chart_version} --wait=false --values - <<EOF",
      "ports:",
      "  web:",
      "    hostPort: 80",
      "  websecure:",
      "    hostPort: 443",
      "deployment:",
      "  kind: DaemonSet",
      "ingressClass:",
      "  enabled: true",
      "  isDefaultClass: true",
      "providers:",
      "  kubernetesIngress:",
      "    enabled: true",
      "EOF",
      "echo 'Traefik installed'"
    ]
  }

  # Install cert-manager
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Installing cert-manager...'",
      "sudo helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true",
      "sudo helm repo update",
      "export KUBECONFIG=/etc/kubernetes/admin.conf && sudo helm install cert-manager jetstack/cert-manager --namespace cert-manager --version ${var.cert_manager_chart_version} --set installCRDs=true --wait=false",
      "echo 'cert-manager installed (background startup)'"
    ]
  }

  # Install local-path-provisioner
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "echo 'Installing local-path-provisioner...'",
      "sudo helm repo add containeroo https://charts.containeroo.ch 2>/dev/null || true",
      "sudo helm repo update",
      "export KUBECONFIG=/etc/kubernetes/admin.conf && sudo helm install local-path-provisioner containeroo/local-path-provisioner --namespace local-path-storage --version ${var.local_path_provisioner_chart_version} --wait=false --values - <<EOF",
      "storageClass:",
      "  defaultClass: true",
      "  name: local-path",
      "EOF",
      "echo 'local-path-provisioner installed (background startup)'"
    ]
  }

  depends_on = [null_resource.fetch_kubeconfig]
}
