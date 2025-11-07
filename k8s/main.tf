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
  
  # Start with local backend, will migrate to remote (GCS/S3) later
  backend "local" {}
}

# Provider configurations
provider "null" {}
provider "local" {}

# Configure Kubernetes provider after kubeconfig is fetched
provider "kubernetes" {
  config_path = var.kubeconfig_local_path
  
  # Ensure provider waits for kubeconfig to exist
  depends_on = [null_resource.fetch_kubeconfig]
}

# Configure Helm provider after kubeconfig is fetched
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_local_path
  }
  
  # Ensure provider waits for kubeconfig to exist
  depends_on = [null_resource.fetch_kubeconfig]
}

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
  ssh_connection = {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.host
    
    # Add bastion configuration if provided
    bastion_host        = var.bastion_host != "" ? var.bastion_host : null
    bastion_user        = var.bastion_user != "" ? var.bastion_user : null
    bastion_port        = var.bastion_host != "" ? var.bastion_port : null
    bastion_private_key = var.bastion_private_key_path != "" ? file(var.bastion_private_key_path) : null
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
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    host        = local.ssh_connection.host
    
    # Bastion settings (optional)
    bastion_host        = local.ssh_connection.bastion_host
    bastion_user        = local.ssh_connection.bastion_user
    bastion_port        = local.ssh_connection.bastion_port
    bastion_private_key = local.ssh_connection.bastion_private_key
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
      "fi"
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
    private_key = local.ssh_connection.private_key
    host        = local.ssh_connection.host
    
    bastion_host        = local.ssh_connection.bastion_host
    bastion_user        = local.ssh_connection.bastion_user
    bastion_port        = local.ssh_connection.bastion_port
    bastion_private_key = local.ssh_connection.bastion_private_key
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
    private_key = local.ssh_connection.private_key
    host        = local.ssh_connection.host
    
    bastion_host        = local.ssh_connection.bastion_host
    bastion_user        = local.ssh_connection.bastion_user
    bastion_port        = local.ssh_connection.bastion_port
    bastion_private_key = local.ssh_connection.bastion_private_key
  }
  
  # Initialize cluster if not already initialized
  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "if [ ! -f /etc/kubernetes/admin.conf ]; then",
      "  sudo kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs",
      "  mkdir -p $HOME/.kube",
      "  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config",
      "  sudo chown $(id -u):$(id -g) $HOME/.kube/config",
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
      type        = local.ssh_connection.type
      user        = local.ssh_connection.user
      private_key = local.ssh_connection.private_key
      host        = local.ssh_connection.host
      
      bastion_host        = local.ssh_connection.bastion_host
      bastion_user        = local.ssh_connection.bastion_user
      bastion_port        = local.ssh_connection.bastion_port
      bastion_private_key = local.ssh_connection.bastion_private_key
    }
    
    inline = [
      "set -euxo pipefail",
      "sudo cp /etc/kubernetes/admin.conf /tmp/kubeconfig",
      "sudo chmod 644 /tmp/kubeconfig"
    ]
  }
  
  # Fetch kubeconfig using local-exec with scp
  provisioner "local-exec" {
    command = var.bastion_host != "" ? (
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} -o ProxyCommand='ssh -W %h:%p -i ${var.bastion_private_key_path != "" ? var.bastion_private_key_path : var.ssh_private_key_path} ${var.bastion_user}@${var.bastion_host} -p ${var.bastion_port}' ${var.ssh_user}@${var.host}:/tmp/kubeconfig ${var.kubeconfig_local_path}"
    ) : (
      "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.host}:/tmp/kubeconfig ${var.kubeconfig_local_path}"
    )
  }
}

# Create necessary namespaces
resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
  
  depends_on = [null_resource.fetch_kubeconfig]
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
  
  depends_on = [null_resource.fetch_kubeconfig]
}

resource "kubernetes_namespace" "local_path_storage" {
  metadata {
    name = "local-path-storage"
  }
  
  depends_on = [null_resource.fetch_kubeconfig]
}

# Step 5: Install Cilium CNI
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = var.cilium_chart_version
  
  values = [<<-EOF
    kubeProxyReplacement: "strict"
    ipam:
      mode: "kubernetes"
    k8sServiceHost: ${var.host}
    k8sServicePort: 6443
  EOF
  ]
  
  timeout = 600
  wait    = true
  
  depends_on = [null_resource.fetch_kubeconfig]
}

# Step 6: Install Traefik Ingress Controller
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = kubernetes_namespace.traefik.metadata[0].name
  version          = var.traefik_chart_version
  create_namespace = false
  
  values = [<<-EOF
    ports:
      web:
        hostPort: 80
      websecure:
        hostPort: 443
    deployment:
      kind: DaemonSet
    ingressClass:
      enabled: true
      isDefaultClass: true
    providers:
      kubernetesIngress:
        enabled: true
  EOF
  ]
  
  timeout = 300
  wait    = true
  
  depends_on = [
    helm_release.cilium,
    kubernetes_namespace.traefik
  ]
}

# Step 7: Install cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  version          = var.cert_manager_chart_version
  create_namespace = false
  
  values = [<<-EOF
    installCRDs: true
    global:
      leaderElection:
        namespace: cert-manager
  EOF
  ]
  
  timeout = 300
  wait    = true
  
  depends_on = [
    helm_release.traefik,
    kubernetes_namespace.cert_manager
  ]
}

# Step 8: Install local-path-provisioner
resource "helm_release" "local_path_provisioner" {
  name             = "local-path-provisioner"
  repository       = "https://charts.containeroo.ch"
  chart            = "local-path-provisioner"
  namespace        = kubernetes_namespace.local_path_storage.metadata[0].name
  version          = var.local_path_provisioner_chart_version
  create_namespace = false
  
  values = [<<-EOF
    storageClass:
      defaultClass: true
      name: local-path
  EOF
  ]
  
  timeout = 300
  wait    = true
  
  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace.local_path_storage
  ]
}

# Optional: Create Let's Encrypt ClusterIssuer (only if email provided)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.acme_email != "" ? 1 : 0
  
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.enable_letsencrypt_staging ? "letsencrypt-staging" : "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = var.enable_letsencrypt_staging ? "https://acme-staging-v02.api.letsencrypt.org/directory" : "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = var.enable_letsencrypt_staging ? "letsencrypt-staging" : "letsencrypt-prod"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "traefik"
            }
          }
        }]
      }
    }
  }
  
  depends_on = [helm_release.cert_manager]
}
