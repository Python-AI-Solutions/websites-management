You are implementing an OpenTofu stack to bootstrap a single-node Kubernetes control plane on a remote Linux host using kubeadm + containerd, then layering add-ons with Helm. I'd like to migrate the current k8s setup in Tofu modules to this.

- Remote host: fresh install is an Debian box reachable via SSH.
- Use containerd with SystemdCgroup=true.
- Use kubeadm to init a single-node control plane (also schedules workloads).
- Networking via Cilium (installed with Helm; no raw manifests).
- Ingress via Traefik (Helm). I do not want NGINX.
- TLS via cert-manager (Helm, installCRDs=true).
- Dynamic storage via local-path-provisioner (Helm) (simple default storage class).
- Fetch kubeconfig to the local repo path and wire providers to it.
- All versions pinned with variables and sensible defaults.
- Idempotent remote steps: guard with checks and file probes; safe to re-tofu apply.


Variables (make these and document in README)
- host (string, required) — remote IP/DNS.
- ssh_user (default "sysadmin").
- ssh_private_key_path (default "~/.ssh/id_ed25519").
- cluster_name (default "xps-cluster").
- kubernetes_version (default "1.30.5").
- pod_cidr (default "10.244.0.0/16").
- service_cidr (default "10.96.0.0/12").
- control_plane_endpoint (default ""; allow empty for single node).
- kubeconfig_local_path (default "./kubeconfig").
- Chart versions (defaults; make vars):
- cilium_chart_version (e.g., "1.16.3").
- traefik_chart_version (e.g., "32.1.0").
- cert_manager_chart_version (e.g., "v1.16.1").
- local_path_provisioner_chart_version (e.g., "0.0.28").

Providers
- null, local, kubernetes, and helm.
- kubernetes/helm must point to the fetched kubeconfig on disk.

Kubeadm config template

Create kubeadm-config.yaml.tmpl using apiVersion: kubeadm.k8s.io/v1beta4 with:
- kubernetesVersion: v${kubernetes_version}
- clusterName: ${cluster_name}
- networking.podSubnet: ${pod_cidr}
- networking.serviceSubnet: ${service_cidr}
- controlPlaneEndpoint: "${control_plane_endpoint}"
- InitConfiguration.nodeRegistration.kubeletExtraArgs.cloud-provider: "external"
Render it via local_file and copy to /tmp/kubeadm-config.yaml on the remote.

Remote host prep (idempotent)

A single null_resource (or two staged ones) over SSH that does:
- swapoff -a and comment swap in /etc/fstab (tolerate re-runs).
- Enable br_netfilter, set net.bridge.bridge-nf-call-iptables=1, net.ipv4.ip_forward=1 (via /etc/sysctl.d/99-k8s.conf; run sysctl --system).
- Install containerd if missing; write /etc/containerd/config.toml (generate if not exists) and set SystemdCgroup = true; systemctl enable --now containerd.
- Install kubeadm, kubelet, kubectl from pkgs.k8s.io repo (guard with command -v kubeadm); apt-mark hold to keep versions stable.
- Place the rendered kubeadm config to /tmp/kubeadm-config.yaml.

Initialize control plane (idempotent)
- If /etc/kubernetes/admin.conf does not exist:
sudo kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs
- Copy admin kubeconfig to $HOME/.kube/config for the SSH user.
- Remove control-plane taint (kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true).

Fetch kubeconfig locally
- Copy /etc/kubernetes/admin.conf to /tmp/kubeconfig and scp it to ${var.kubeconfig_local_path} locally. Mark output as sensitive.

Helm add-ons (all pinned, all via helm_release)
	1.	Cilium
- Repo: https://helm.cilium.io
- Name: cilium, ns: kube-system
- Values to set at minimum:
- kubeProxyReplacement: "strict" (or "partial"; pick a sensible default & comment)
- ipam.mode: "kubernetes"
- Ensure it respects the configured pod_cidr
- Wait for DaemonSet rollout.
	2.	Traefik (Ingress)
- Repo: https://traefik.github.io/charts
- Name: traefik, ns: traefik
- Values:
- Expose via hostPorts for single-node (80/443) OR NodePort. Default to hostPorts for simplicity.
- Set service.type: NodePort only if hostPorts are disabled.
- Enable ingressClass: "traefik" and set it as default ingress class (annotation).
- Optionally enable dashboard but do not expose publicly by default.
	3.	cert-manager
- Repo: https://charts.jetstack.io
- Name: cert-manager, ns: cert-manager
- Set installCRDs=true.
- Create a sample ClusterIssuer (Let’s Encrypt HTTP-01) targeting Traefik ingress class; make it optional with a Tofu variable toggle.
	4.	local-path-provisioner
- Repo: https://charts.containeroo.ch (or rancher if you prefer, but pick one and pin)
- Name: local-path-provisioner, ns: local-path-storage
- Set as default StorageClass.

Important: Make Helm resources depend on the kubeconfig fetch and sequentially where needed (e.g., cert-manager after CRDs, Traefik after cluster ready). Use wait = true or rollout checks to avoid flapping on re-apply.

Outputs
- kubeconfig_path (sensitive, absolute).
- Optionally: join_command (produce via kubeadm token create --print-join-command and store to a local output file; not mandatory).

README.md (concise)
- Prereqs: SSH to host, outbound internet
- Quickstart:

cd k8s
tofu init
tofu apply \
  -var 'host=YOUR_SERVER_IP' \
  -var 'ssh_user=sysadmin' \
  -var 'ssh_private_key_path=~/.ssh/id_ed25519' \
  -var 'cluster_name=xps'
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A


- Verify add-ons:

kubectl -n kube-system get ds cilium
kubectl -n traefik get deploy traefik
kubectl -n cert-manager get pods
kubectl get storageclass


- Sample ClusterIssuer YAML using Traefik as the solver (optional block in README).

Code quality & style
- Pin all versions; expose pins via variables with documented defaults.
- Use small, readable provisioner scripts; set -euxo pipefail.
- Add guards for idempotence (if ! command -v …, existence checks on files/services).
- No hard-coded email/domains; leave placeholders clearly marked.
- Keep everything easy to diff & migrate into an existing Tofu repo (modular blocks, minimal surprises).

- Output a one-liner to port-forward Traefik dashboard locally (commented).
- Commented example of a simple Ingress using Traefik + cert-manager annotations.

Deliverables: the full Tofu stack files above, ready to tofu apply on a clean debian host and safe to re-apply. Do not include vendor-specific cloud code. Keep it short, pinned, and migration-friendly.
