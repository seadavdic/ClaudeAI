# cert-manager - Automatic SSL/TLS Certificate Management

This document explains the cert-manager setup for automatic SSL/TLS certificate management in your Kubernetes cluster.

## 📋 Overview

**cert-manager** is a Kubernetes add-on that automates the management and issuance of TLS certificates.

| Component | Version | Purpose |
|-----------|---------|---------|
| **cert-manager** | 1.13.3 | Certificate management controller |
| **ClusterIssuer** | CA-based | Issues certificates from cluster CA |
| **Certificates** | 5 services | Auto-renewed every 90 days |
| **Architecture** | ARM32 compatible | Runs on Raspberry Pi |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   CERT-MANAGER CERTIFICATE FLOW                 │
└─────────────────────────────────────────────────────────────────┘

  Step 1: Bootstrap CA
  ┌──────────────────────────────┐
  │  Self-Signed ClusterIssuer   │
  │  (selfsigned-issuer)         │
  └──────────┬───────────────────┘
             │
             │ Creates
             ▼
  ┌──────────────────────────────┐
  │  CA Certificate              │
  │  (ca-key-pair secret)        │
  │  - Valid: 10 years           │
  │  - RSA 4096-bit              │
  │  - Root CA for cluster       │
  └──────────┬───────────────────┘
             │
             │ Used by
             ▼
  Step 2: CA Issuer
  ┌──────────────────────────────┐
  │  CA ClusterIssuer            │
  │  (ca-issuer)                 │
  └──────────┬───────────────────┘
             │
             │ Issues certificates
             │
     ┌───────┼───────┬───────────┬───────────┐
     │       │       │           │           │
     ▼       ▼       ▼           ▼           ▼
  ┌─────┐ ┌─────┐ ┌─────┐  ┌──────────┐ ┌──────────┐
  │Grafana│Prom│SmartBiz│RabbitMQ│Alertmgr│
  │ TLS  │ TLS │  TLS  │   TLS   │   TLS   │
  └──┬──┘ └──┬─┘ └──┬──┘  └───┬───┘ └───┬───┘
     │       │       │         │         │
     │       │       │         │         │
     ▼       ▼       ▼         ▼         ▼
  Step 3: Service Access
  ┌───────────────────────────────────────────┐
  │  HTTPS Access:                            │
  │  • https://grafana.local:30683            │
  │  • https://prometheus.local:30683         │
  │  • https://smartbiz.local:30683           │
  │  • https://rabbitmq.local:30683           │
  │  • https://alertmanager.local:30683       │
  └───────────────────────────────────────────┘
```

## 🔐 Security Architecture

### Certificate Hierarchy

```
Root CA (Self-Signed)
  ├─ CN: cluster-ca
  ├─ Validity: 10 years
  ├─ Key: RSA 4096-bit
  └─ Stored: ca-key-pair secret (cert-manager namespace)
      │
      ├─► Service Certificates (Signed by CA)
      │   ├─ grafana-tls-secret (grafana namespace)
      │   ├─ prometheus-tls-secret (prometheus namespace)
      │   ├─ smartbiz-tls-secret (smartbiz namespace)
      │   ├─ rabbitmq-tls-secret (rabbitmq namespace)
      │   └─ alertmanager-tls-secret (prometheus namespace)
      │
      └─► Properties
          ├─ Validity: 90 days
          ├─ Auto-renewal: 15 days before expiry
          └─ Organization: RaspberryPi-Cluster
```

### Why This Approach?

**Self-Signed CA Issuer** (Our Choice):
- ✅ Works for internal services (*.local domains)
- ✅ No external dependencies
- ✅ Full control over certificate lifecycle
- ✅ Free and immediate
- ⚠️ Requires manual CA trust on client devices

**Let's Encrypt** (Alternative):
- ✅ Trusted by all browsers
- ❌ Requires public DNS (not *.local domains)
- ❌ Requires DNS-01 or HTTP-01 validation
- ❌ Rate limits (50 certs/week per domain)

For internal cluster services, self-signed CA is the perfect choice!

## 📜 Deployed Components

### 1. cert-manager Controller

**Deployment:** `apps/cert-manager/helmrelease.yaml`

```yaml
Components:
  - controller: Issues and renews certificates
  - webhook: Validates CertificateRequests
  - cainjector: Injects CA bundles into webhooks

Resource Limits (per component):
  CPU: 10m request, 100m limit
  Memory: 32Mi request, 128Mi limit

ARM32 Compatibility: ✅
  nodeSelector: kubernetes.io/arch: arm
```

### 2. ClusterIssuers

**File:** `apps/cert-manager/clusterissuer.yaml`

```yaml
selfsigned-issuer:
  Purpose: Bootstrap the CA certificate
  Type: Self-signed
  Usage: Creates the initial CA cert

ca-issuer:
  Purpose: Issue service certificates
  Type: CA
  CA Secret: ca-key-pair (cert-manager namespace)
  Usage: Signs all service certificates
```

### 3. Certificates

**File:** `apps/cert-manager/certificates.yaml`

All certificates are automatically renewed 15 days before expiry.

| Service | Hostname | Namespace | Secret Name |
|---------|----------|-----------|-------------|
| Grafana | grafana.local | grafana | grafana-tls-secret |
| Prometheus | prometheus.local | prometheus | prometheus-tls-secret |
| SmartBiz | smartbiz.local | smartbiz | smartbiz-tls-secret |
| RabbitMQ | rabbitmq.local | rabbitmq | rabbitmq-tls-secret |
| Alertmanager | alertmanager.local | prometheus | alertmanager-tls-secret |

### 4. TLS-Enabled Ingresses

All Ingresses updated with TLS configuration:

```yaml
spec:
  tls:
  - hosts:
    - <service>.local
    secretName: <service>-tls-secret

  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.middlewares: default-redirect-https@kubernetescrd
```

### 5. HTTP to HTTPS Redirect

**Middleware:** `apps/cert-manager/redirect-middleware.yaml`

Automatically redirects all HTTP traffic to HTTPS (permanent 301 redirect).

## 🚀 Accessing Services with HTTPS

### Before cert-manager:
```
http://grafana.local:30683
http://prometheus.local:30683
http://smartbiz.local:30683
http://rabbitmq.local:30683
```

### After cert-manager:
```
https://grafana.local:30683  ← Automatically redirects from HTTP
https://prometheus.local:30683
https://smartbiz.local:30683
https://rabbitmq.local:30683
```

## 🔧 Trusting the CA Certificate (Client Side)

Your browser will show a security warning because the CA is not publicly trusted. You can:

### Option 1: Accept Browser Warning (Quick & Simple)
1. Visit `https://grafana.local:30683`
2. Click "Advanced" → "Proceed to grafana.local"
3. Repeat for each service

### Option 2: Trust the CA Certificate (Permanent Solution)

This makes your browser trust ALL certificates issued by the cluster CA.

**On Windows:**

```powershell
# 1. Export the CA certificate from the cluster
kubectl get secret ca-key-pair -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > cluster-ca.crt

# 2. Import into Windows certificate store
certutil -addstore -f "Root" cluster-ca.crt

# 3. Restart browser
```

**On macOS:**

```bash
# 1. Export the CA certificate
kubectl get secret ca-key-pair -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > cluster-ca.crt

# 2. Import into Keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cluster-ca.crt

# 3. Restart browser
```

**On Linux:**

```bash
# 1. Export the CA certificate
kubectl get secret ca-key-pair -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > cluster-ca.crt

# 2. Copy to trusted certificates (Ubuntu/Debian)
sudo cp cluster-ca.crt /usr/local/share/ca-certificates/cluster-ca.crt
sudo update-ca-certificates

# 3. For Firefox, add manually in Settings → Certificates → Authorities
```

After trusting the CA:
- ✅ No more browser warnings
- ✅ Green padlock icon in address bar
- ✅ Applies to all cluster services

## 📊 Monitoring Certificates

### Check Certificate Status

```bash
# List all certificates
kubectl get certificates -A

# Check specific certificate
kubectl describe certificate grafana-tls -n grafana

# View certificate details
kubectl get certificate grafana-tls -n grafana -o yaml

# Check certificate secret
kubectl get secret grafana-tls-secret -n grafana -o yaml
```

### Expected Output

```bash
$ kubectl get certificates -A

NAMESPACE     NAME               READY   SECRET                    AGE
cert-manager  ca-certificate     True    ca-key-pair               5m
grafana       grafana-tls        True    grafana-tls-secret        5m
prometheus    prometheus-tls     True    prometheus-tls-secret     5m
prometheus    alertmanager-tls   True    alertmanager-tls-secret   5m
rabbitmq      rabbitmq-tls       True    rabbitmq-tls-secret       5m
smartbiz      smartbiz-tls       True    smartbiz-tls-secret       5m
```

**READY=True** means:
- ✅ Certificate issued successfully
- ✅ Secret created with tls.crt and tls.key
- ✅ Certificate valid and not expired
- ✅ Auto-renewal configured

### Check Certificate Expiry

```bash
# View certificate expiry dates
kubectl get certificate -A -o custom-columns=\
'NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
READY:.status.conditions[0].status,\
EXPIRY:.status.notAfter'
```

### Certificate Renewal

Certificates automatically renew 15 days before expiry. To force renewal:

```bash
# Delete the secret (cert-manager will recreate it)
kubectl delete secret grafana-tls-secret -n grafana

# Wait for cert-manager to reissue
kubectl get certificate grafana-tls -n grafana -w
```

## 🔍 Troubleshooting

### Issue: Certificate shows READY=False

```bash
# Check certificate status
kubectl describe certificate grafana-tls -n grafana

# Check CertificateRequest
kubectl get certificaterequest -n grafana

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f
```

### Issue: Browser shows "NET::ERR_CERT_AUTHORITY_INVALID"

**This is expected!** Your browser doesn't trust the self-signed CA. Solutions:
1. Accept the browser warning (temporary)
2. Trust the CA certificate system-wide (permanent)

### Issue: Certificate issued but HTTPS not working

```bash
# Check Traefik is using the certificate
kubectl logs -n kube-system deployment/traefik -f

# Verify TLS secret exists
kubectl get secret grafana-tls-secret -n grafana

# Check Ingress configuration
kubectl describe ingress grafana -n grafana
```

### Issue: HTTP not redirecting to HTTPS

```bash
# Check redirect middleware exists
kubectl get middleware redirect-https -n default

# Verify Ingress has middleware annotation
kubectl get ingress grafana -n grafana -o yaml | grep middleware
```

## 🔄 Certificate Lifecycle

```
Day 0: Certificate Issued
  ├─ cert-manager creates Certificate resource
  ├─ CertificateRequest generated
  ├─ CA signs the certificate
  └─ Secret created with tls.crt and tls.key

Day 1-74: Valid Period
  ├─ Certificate used by Traefik for TLS termination
  └─ No action needed

Day 75: Renewal Window Opens (15 days before expiry)
  ├─ cert-manager detects renewal needed
  ├─ New CertificateRequest created
  ├─ New certificate issued
  └─ Secret updated with new certificate

Day 90: Old Certificate Expires
  └─ Already replaced with new certificate on Day 75

Day 91-164: New Certificate Valid
  └─ Cycle repeats
```

## 📈 Prometheus Metrics

cert-manager exposes Prometheus metrics on port 9402:

```yaml
# Key Metrics:
certmanager_certificate_expiration_timestamp_seconds
  - Certificate expiry time (Unix timestamp)

certmanager_certificate_ready_status
  - Certificate ready status (1=ready, 0=not ready)

certmanager_controller_sync_call_count
  - Number of sync operations

# Add to Prometheus scrape config:
- job_name: 'cert-manager'
  static_configs:
    - targets: ['cert-manager.cert-manager.svc.cluster.local:9402']
```

## 🔗 Related Documentation

- [SEALED-SECRETS.md](SEALED-SECRETS.md) - Encrypted secrets in Git
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Cluster architecture
- [Official cert-manager Docs](https://cert-manager.io/docs/)

## 📝 Summary

✅ **cert-manager deployed** - Automatic certificate management
✅ **CA hierarchy created** - Self-signed root CA + service certificates
✅ **5 services secured** - Grafana, Prometheus, SmartBiz, RabbitMQ, Alertmanager
✅ **Auto-renewal configured** - Certificates renew 15 days before expiry
✅ **HTTP→HTTPS redirect** - Automatic upgrade to secure connections
✅ **ARM32 compatible** - Runs on Raspberry Pi cluster

**Next Steps:**
- Trust the CA certificate on your client devices (optional but recommended)
- Add Prometheus scrape config for cert-manager metrics
- Consider OAuth2 Proxy for authentication layer (requires HTTPS ✅)

---

**Created:** 2026-01-08
**cert-manager Version:** 1.13.3
**Certificate Validity:** 90 days
**Auto-Renewal:** 15 days before expiry
**Encryption:** RSA 4096-bit
