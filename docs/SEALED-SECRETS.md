# Sealed Secrets - Secure Credentials Management

## 🔐 Overview

This cluster uses **Sealed Secrets** to securely manage credentials in Git. Sealed Secrets encrypt your secrets using asymmetric cryptography, allowing you to safely commit encrypted credentials to your repository while only the cluster can decrypt them.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SEALED SECRETS WORKFLOW                       │
└─────────────────────────────────────────────────────────────────┘

  Developer                Git Repository              Cluster
  ─────────                ──────────────              ───────

  1. Create Secret         2. Encrypt                  3. Deploy
  ┌──────────┐            ┌──────────┐                ┌──────────┐
  │ username │  kubeseal  │ AgBYCC.. │    Flux CD     │ username │
  │ password │  ───────>  │ AgA2r7.. │    ────────>   │ password │
  │          │            │ encrypted│                │ decrypted│
  └──────────┘            └──────────┘                └──────────┘
   Plain Text              Safe for Git                In Cluster
                         (SealedSecret)                 (Secret)

  🔑 Encryption: RSA-4096 (public key)
  🔓 Decryption: Only cluster controller (private key)
```

## 📦 What's Protected

All sensitive credentials in this cluster are sealed:

### RabbitMQ Credentials
- **Location**: `apps/rabbitmq/sealed-secret.yaml`
- **Namespace**: rabbitmq
- **Keys**: username, password
- **Used by**: RabbitMQ deployment, Order Pipeline services

### PostgreSQL Database
- **Location**: `apps/smartbiz-db/sealed-secret.yaml`
- **Namespace**: smartbiz
- **Keys**: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
- **Used by**: PostgreSQL deployment, SmartBiz API

### Grafana Admin
- **Location**: `apps/grafana/sealed-secret.yaml`
- **Namespace**: grafana
- **Keys**: admin-user, admin-password
- **Default credentials**: admin / Grafana2026!Secure
- **Used by**: Grafana HelmRelease

### Order Pipeline
- **Location**: `apps/order-pipeline/sealed-secret.yaml`
- **Namespace**: order-pipeline
- **Keys**: username, password
- **Used by**: order-generator, payment-service, fulfillment-service, notification-service

## 🛠️ Installation

The Sealed Secrets controller is installed using the official manifest:

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.34.0/controller.yaml
```

**Controller location**: kube-system namespace

## 🔧 Creating New Sealed Secrets

### Prerequisites

Install kubeseal CLI:
```bash
# Windows
curl -sLO "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.34.0/kubeseal-0.34.0-windows-amd64.tar.gz"
tar -xzf kubeseal-0.34.0-windows-amd64.tar.gz

# Linux
curl -sLO "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.34.0/kubeseal-0.34.0-linux-amd64.tar.gz"
tar -xzf kubeseal-0.34.0-linux-amd64.tar.gz
```

### Step-by-Step Guide

1. **Create a regular Kubernetes Secret** (do NOT apply to cluster):

```bash
cat << EOF | kubeseal --format=yaml > sealed-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
type: Opaque
stringData:
  username: myuser
  password: mypassword
EOF
```

2. **The sealed secret is created** in `sealed-secret.yaml`:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
  namespace: my-namespace
spec:
  encryptedData:
    password: AgBYCC5PImB+Ajg...  # Encrypted!
    username: AgCjXOssCmppHZh...  # Encrypted!
```

3. **Add to your app's kustomization.yaml**:

```yaml
resources:
  - sealed-secret.yaml
  - deployment.yaml
```

4. **Reference in your deployment**:

```yaml
env:
- name: USERNAME
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: username
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: password
```

5. **Commit and push**:

```bash
git add sealed-secret.yaml
git commit -m "Add sealed secret for my-app"
git push
```

6. **Flux will deploy it automatically**, and the Sealed Secrets controller will decrypt it into a regular Kubernetes Secret.

## 🔄 Updating Existing Secrets

To change a password or credential:

1. Create a new sealed secret with the updated values (same process as above)
2. Replace the old sealed-secret.yaml file
3. Commit and push
4. Flux will update the secret automatically
5. Restart pods to pick up the new credentials (if needed):

```bash
kubectl rollout restart deployment/my-app -n my-namespace
```

## ✅ Verification

Check if sealed secrets are working:

```bash
# List all SealedSecrets
kubectl get sealedsecrets -A

# Check if they've been unsealed into Secrets
kubectl get secrets -n <namespace>

# View the SealedSecret (encrypted - safe!)
kubectl get sealedsecret <name> -n <namespace> -o yaml

# You CANNOT view the decrypted Secret from Git
# Only the cluster can decrypt it
```

## 🔐 Security Benefits

1. **Safe Git Storage**: Encrypted secrets can be committed to public repositories
2. **GitOps Compatible**: Works seamlessly with Flux CD
3. **Asymmetric Encryption**: Only the cluster can decrypt
4. **Namespace Scoped**: Secrets are bound to specific namespaces
5. **Audit Trail**: All changes tracked in Git history
6. **No Secret Sprawl**: All credentials in one version-controlled location

## 🚨 Important Security Notes

- **Backup the private key**: The Sealed Secrets controller's private key is critical for decryption. It's stored as a Secret in kube-system namespace.
- **Disaster recovery**: If you lose the cluster and the private key, you cannot decrypt old sealed secrets. Back up the keys!
- **Namespace binding**: By default, SealedSecrets are bound to their namespace. Don't move them between namespaces.

## 📚 Further Reading

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)

---

**Next Security Steps**: Consider implementing SSL/TLS certificates (cert-manager) and OAuth2 authentication (Step 2 & 3 in the security roadmap).
