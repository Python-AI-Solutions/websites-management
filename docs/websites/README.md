# Website Deployment Documentation

Guidelines for deploying and managing websites in this project.

## Overview

Websites in this project can be deployed to:
- **Kubernetes cluster** (via Traefik ingress)
- **Cloudflare Pages** (static sites)

This documentation covers deployment, configuration, and best practices.

## Quick Start

### Deploy to Kubernetes

Websites running on the Kubernetes cluster use Traefik for ingress routing.

**Steps:**
1. Ensure Kubernetes cluster is running (see [../infrastructure/setup.md](../infrastructure/setup.md))
2. Create website Kubernetes manifests
3. Deploy via kubectl or GitOps (ArgoCD)
4. Access via domain configured in Traefik Ingress

### Deploy to Cloudflare Pages

Static websites can be deployed directly to Cloudflare Pages.

**Steps:**
1. Configure Cloudflare Pages in the `sites/` directory
2. Connect to your git repository
3. Configure build and deployment settings
4. Cloudflare automatically deploys on git push

## Directory Structure

```
sites/                          ← Website files
├── [website-projects]/
│   ├── public/                 ← Static files
│   ├── src/                    ← Source code
│   └── [build config]          ← Build configuration
└── [other websites]/
```

## Deployment Methods

### Method 1: Kubernetes Ingress

For dynamic applications or services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  ingressClassName: traefik
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

**Access:**
```bash
# Connect via WireGuard VPN first
# Then access via domain
```

### Method 2: Cloudflare Pages

For static websites:

1. Push code to git repository
2. Cloudflare automatically detects and builds
3. Sites available at `https://your-site.pages.dev`
4. Custom domains configured in Cloudflare dashboard

## Configuration

### Kubernetes Deployment

See [../infrastructure/setup.md](../infrastructure/setup.md) for cluster access.

```bash
# Deploy application to cluster
kubectl apply -f deployment.yaml

# Check status
kubectl get ingress
kubectl get svc

# View logs
kubectl logs -f [pod-name]
```

### Cloudflare Configuration

Configure in Cloudflare dashboard:
- DNS records
- SSL/TLS settings
- Caching rules
- Page rules

## Troubleshooting

### Website Not Accessible

**Kubernetes:**
```bash
# Check ingress status
kubectl describe ingress myapp-ingress

# Check service
kubectl get svc myapp

# Check pod logs
kubectl logs -f deployment/myapp
```

**Cloudflare Pages:**
- Check build logs in Cloudflare dashboard
- Verify DNS records are correct
- Check SSL certificate status

### Build Failures

**Cloudflare Pages:**
1. Check build logs: Settings → Build, Deployments & Pages → View Build Log
2. Verify build command is correct
3. Check for environment variable requirements

**Kubernetes:**
1. Check pod logs: `kubectl logs [pod-name]`
2. Check resource requests/limits
3. Verify image availability

## Best Practices

### Security

- Use HTTPS for all websites
- Keep certificates up-to-date (cert-manager handles this in K8s)
- Use strong passwords for any admin panels
- Keep dependencies updated

### Performance

- Enable caching in Cloudflare Pages
- Use CDN for static assets
- Optimize images before deployment
- Monitor performance metrics

### Reliability

- Use persistent storage for state data
- Configure backups
- Monitor uptime
- Plan for high availability

## DNS Configuration

### For Kubernetes Websites

Point DNS to Traefik ingress IP:

```bash
# Get ingress IP
kubectl get ingress -A

# Add DNS record
A record: yourdomain.com → [ingress-ip]
```

### For Cloudflare Pages

Cloudflare provides nameservers:

```
Nameserver 1: [cloudflare-ns1].ns.cloudflare.com
Nameserver 2: [cloudflare-ns2].ns.cloudflare.com
```

Update domain registrar to use Cloudflare nameservers.

## SSL/TLS Certificates

### Kubernetes

cert-manager handles automatic certificate management:

```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

**Status:**
```bash
kubectl get certificate -A
kubectl describe certificate [cert-name]
```

### Cloudflare Pages

Cloudflare provides free SSL certificates automatically.

## Deployment Checklist

Before deploying:

- [ ] DNS records configured
- [ ] SSL certificate ready (or auto-generated)
- [ ] Application builds successfully
- [ ] Environment variables configured
- [ ] Database/storage ready (if needed)
- [ ] Backups configured (if needed)
- [ ] Monitoring configured

## Support

**Website deployment questions?**

1. Check relevant deployment method section above
2. Review troubleshooting section
3. Check infrastructure docs: [../infrastructure/](../infrastructure/)
4. See project [../README.md](../README.md) for support

---

**Need infrastructure help?** → [../infrastructure/setup.md](../infrastructure/setup.md)

**Need general project info?** → [../README.md](../README.md)

