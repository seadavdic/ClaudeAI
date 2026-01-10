# OAuth2 Authentication with GitHub

## Overview

OAuth2 Proxy provides centralized authentication for Kubernetes services using GitHub as the identity provider. This setup protects services like Grafana with enterprise-grade authentication without requiring individual service configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      OAUTH2 AUTHENTICATION FLOW                         │
└─────────────────────────────────────────────────────────────────────────┘

  Step 1: User Access
  ┌──────────────────┐
  │  User's Browser  │
  │                  │
  │  Visit:          │
  │  grafana.local   │
  └────────┬─────────┘
           │
           │ HTTP Request
           │
           ▼
  Step 2: Traefik Ingress
  ┌──────────────────────────────┐
  │  Traefik (TLS Termination)   │
  │  Port: 32742 (HTTPS)         │
  │  Host: grafana.local         │
  └────────┬─────────────────────┘
           │
           │ Routes to service
           │
           ▼
  Step 3: OAuth2 Proxy
  ┌────────────────────────────────────────┐
  │  OAuth2 Proxy (grafana namespace)     │
  │  Port: 4180                            │
  │                                        │
  │  Checks: Session cookie present?      │
  │  ├─ Yes → Forward to Grafana          │
  │  └─ No → Redirect to GitHub           │
  └────────┬───────────────────────────────┘
           │
           │ No session cookie
           │
           ▼
  Step 4: GitHub OAuth
  ┌────────────────────────────────────────┐
  │  GitHub OAuth App                      │
  │  https://github.com/login/oauth        │
  │                                        │
  │  User authenticates with:              │
  │  ├─ GitHub username/password           │
  │  ├─ Two-factor authentication (if set) │
  │  └─ Approves application access        │
  └────────┬───────────────────────────────┘
           │
           │ OAuth callback with code
           │
           ▼
  Step 5: Token Exchange
  ┌────────────────────────────────────────┐
  │  OAuth2 Proxy validates code           │
  │                                        │
  │  1. Exchange code for access token    │
  │  2. Fetch user info from GitHub       │
  │  3. Create session cookie             │
  │  4. Redirect to original URL          │
  └────────┬───────────────────────────────┘
           │
           │ Session cookie set
           │
           ▼
  Step 6: Grafana Access
  ┌────────────────────────────────────────┐
  │  OAuth2 Proxy → Grafana               │
  │                                        │
  │  Headers forwarded:                   │
  │  ├─ X-Auth-Request-User               │
  │  ├─ X-Auth-Request-Email              │
  │  ├─ X-Forwarded-User                  │
  │  └─ Authorization (access token)      │
  └────────┬───────────────────────────────┘
           │
           │ Authenticated request
           │
           ▼
  Step 7: Service Response
  ┌────────────────────────────────────────┐
  │  Grafana Dashboard                     │
  │  User logged in as: user@example.com   │
  └────────────────────────────────────────┘
```

## Components

### 1. OAuth2 Proxy Deployment

**Location:** `apps/oauth2-proxy/grafana-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy-grafana
  namespace: grafana
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
        args:
          - --provider=github
          - --email-domain=*
          - --upstream=http://grafana-grafana.grafana.svc.cluster.local:80
          - --http-address=0.0.0.0:4180
          - --redirect-url=https://grafana.local:32742/oauth2/callback
          - --cookie-secure=true
          - --cookie-samesite=lax
          - --reverse-proxy=true
          - --pass-access-token=true
          - --pass-user-headers=true
          - --set-xauthrequest=true
```

**Key Configuration:**
- `--provider=github` - Use GitHub as OAuth provider
- `--email-domain=*` - Allow any GitHub email domain
- `--upstream` - Backend service to protect (Grafana)
- `--redirect-url` - GitHub OAuth callback URL
- `--cookie-secure=true` - Require HTTPS for cookies
- `--cookie-samesite=lax` - Allow OAuth callback flow
- `--reverse-proxy=true` - Trust X-Forwarded headers from Traefik

### 2. Sealed Secrets

**Location:** `apps/oauth2-proxy/sealed-secret.yaml`

Encrypted credentials stored safely in Git:
- `client-id` - GitHub OAuth App Client ID
- `client-secret` - GitHub OAuth App Client Secret
- `cookie-secret` - Session encryption key (32-byte base64)

**Generate cookie secret:**
```bash
openssl rand -base64 32
```

### 3. Service

**Location:** `apps/oauth2-proxy/grafana-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy-grafana
  namespace: grafana
spec:
  ports:
  - port: 4180
    targetPort: 4180
  selector:
    app: oauth2-proxy-grafana
```

### 4. Ingress Modification

**Location:** `apps/grafana/ingress.yaml`

Modified to route through OAuth2 Proxy instead of directly to Grafana:

```yaml
spec:
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy-grafana  # Changed from grafana-grafana
            port:
              number: 4180  # Changed from 80
```

## GitHub OAuth App Setup

### Creating a GitHub OAuth App

1. Navigate to GitHub Settings
2. Go to **Developer settings** → **OAuth Apps** → **New OAuth App**
3. Fill in application details:
   - **Application name:** Kubernetes Grafana (or your choice)
   - **Homepage URL:** `https://grafana.local:32742`
   - **Authorization callback URL:** `https://grafana.local:32742/oauth2/callback`
4. Click **Register application**
5. Note the **Client ID**
6. Generate a new **Client Secret** and save it securely

### Required Scopes

OAuth2 Proxy with GitHub provider requires:
- `user:email` - Read user email addresses (default scope)

This is automatically included when users authorize the application.

## Deployment Process

### 1. Create GitHub OAuth App
Follow the steps above to get Client ID and Client Secret.

### 2. Generate Cookie Secret
```bash
openssl rand -base64 32
# Example output: AsDrsqfaVGnY3uAPk9qpgUqUJsF5HM7zpq7DS55dgkc=
```

### 3. Create Sealed Secrets

**Option A: Using kubeseal (recommended for GitOps)**
```bash
# Create temporary secret
kubectl create secret generic oauth2-proxy-secrets \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=YOUR_COOKIE_SECRET \
  --namespace=grafana \
  --dry-run=client -o yaml > temp-secret.yaml

# Seal it
kubeseal --format=yaml < temp-secret.yaml > apps/oauth2-proxy/sealed-secret.yaml

# Clean up
rm temp-secret.yaml
```

**Option B: Manual creation (if kubeseal unavailable)**
```bash
kubectl create secret generic oauth2-proxy-secrets \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=YOUR_COOKIE_SECRET \
  --namespace=grafana
```

### 4. Deploy via GitOps

Commit all files to Git:
```bash
git add apps/oauth2-proxy/
git add apps/grafana/ingress.yaml
git commit -m "Add OAuth2 authentication with GitHub for Grafana"
git push
```

Flux CD will automatically deploy within 1 minute.

### 5. Force Immediate Reconciliation
```bash
flux reconcile kustomization apps --with-source
```

### 6. Verify Deployment
```bash
# Check OAuth2 Proxy pod
kubectl get pods -n grafana -l app=oauth2-proxy-grafana

# Check logs
kubectl logs -n grafana deployment/oauth2-proxy-grafana

# Check service
kubectl get svc -n grafana oauth2-proxy-grafana
```

## Access Points

### Local Network (HTTPS - OAuth Protected)
```
URL: https://grafana.local:32742
Authentication: GitHub OAuth required
```

When you visit this URL:
1. If not authenticated → Redirected to GitHub login
2. Authenticate with GitHub credentials
3. Approve application access (first time only)
4. Redirected back to Grafana
5. Session cookie stored (valid until expiry)

### Cloudflare Tunnel (No Authentication)
```
URL: https://your-tunnel-name.trycloudflare.com
Authentication: None (bypasses OAuth2 Proxy)
```

The Cloudflare tunnel connects directly to Grafana service, bypassing OAuth2 Proxy.
This allows external access without authentication if needed.

## Traffic Flow Comparison

### With OAuth2 (Local Access)
```
Browser → Traefik:32742 → oauth2-proxy-grafana:4180 → grafana-grafana:80
         (HTTPS)          (Session check)             (Protected)
```

### Without OAuth2 (Cloudflare)
```
Browser → Cloudflare → cloudflared pod → grafana-grafana:80
         (HTTPS)                        (Direct access)
```

## Cookie Configuration

### Important Cookie Settings

```yaml
--cookie-secure=true        # Require HTTPS (important for security)
--cookie-samesite=lax       # Allow OAuth callback flow
--reverse-proxy=true        # Trust X-Forwarded-* headers
```

### Cookie Behavior
- **Name:** `_oauth2_proxy`
- **Domain:** Request hostname (e.g., `grafana.local`)
- **Path:** `/`
- **Expiry:** 168 hours (7 days) default
- **Secure:** Yes (HTTPS only)
- **SameSite:** Lax (allows OAuth redirects)

## Session Management

### Session Duration
Default: 168 hours (7 days)

**To customize:**
```yaml
args:
  - --cookie-expire=24h  # 24 hour sessions
```

### Session Refresh
OAuth2 Proxy automatically refreshes tokens if the provider supports it.
GitHub OAuth tokens are long-lived and don't require frequent refresh.

### Manual Logout
```
URL: https://grafana.local:32742/oauth2/sign_out
```

This clears the session cookie and requires re-authentication.

## Security Considerations

### ✅ What's Protected
- **Cookie encryption:** Session cookies encrypted with cookie-secret
- **HTTPS only:** Cookies only sent over TLS connections
- **CSRF protection:** Built-in CSRF token validation
- **Token security:** Access tokens passed to backend securely
- **Secrets management:** Credentials encrypted with Sealed Secrets

### ⚠️ Important Notes
1. **Cookie secret rotation:** If you rotate the cookie secret, all users must re-authenticate
2. **Client secret security:** Protect your GitHub Client Secret carefully
3. **Callback URL validation:** GitHub validates redirect URLs against configured callback
4. **Email domain filtering:** Currently set to `*` (all domains) - restrict if needed
5. **Session persistence:** Sessions survive pod restarts (stored in cookies)

### Restricting Access by Email Domain

To allow only specific email domains:
```yaml
args:
  - --email-domain=yourcompany.com
  - --email-domain=partner.com
```

Or use GitHub organization membership:
```yaml
args:
  - --github-org=your-github-org
  - --github-team=your-github-team
```

## Troubleshooting

### Issue: "Unable to find a valid CSRF token"

**Cause:** Cookie configuration preventing CSRF cookie storage

**Solution:**
1. Ensure `--cookie-samesite=lax` is set
2. Verify `--reverse-proxy=true` is enabled
3. Check browser allows cookies for the domain
4. Clear browser cookies and try again

**Logs to check:**
```bash
kubectl logs -n grafana deployment/oauth2-proxy-grafana | grep -i csrf
```

### Issue: "Invalid redirect URI"

**Cause:** GitHub OAuth App callback URL doesn't match configured URL

**Solution:**
1. Verify GitHub OAuth App callback URL: `https://grafana.local:32742/oauth2/callback`
2. Ensure `--redirect-url` matches exactly
3. Check for typos in domain or port

### Issue: "403 Forbidden" after successful GitHub login

**Cause:** Email domain restriction or organization access

**Solution:**
1. Check `--email-domain` setting (use `*` to allow all)
2. If using `--github-org`, ensure user is member
3. Review OAuth2 Proxy logs for rejection reason

### Issue: Session expires immediately

**Cause:** Cookie not being set or stored

**Solution:**
1. Verify HTTPS is being used (cookies marked secure)
2. Check browser cookie settings
3. Test cookie expiry: `--cookie-expire=24h`
4. Review OAuth2 Proxy logs during login

### Viewing Logs
```bash
# Follow OAuth2 Proxy logs
kubectl logs -n grafana deployment/oauth2-proxy-grafana -f

# Search for authentication events
kubectl logs -n grafana deployment/oauth2-proxy-grafana | grep -i auth

# Check for errors
kubectl logs -n grafana deployment/oauth2-proxy-grafana | grep -i error
```

## Metrics & Monitoring

OAuth2 Proxy exposes Prometheus metrics at `/metrics` endpoint.

**Available Metrics:**
- `oauth2_proxy_requests_total` - Total HTTP requests
- `oauth2_proxy_authentication_failures_total` - Failed authentications
- `oauth2_proxy_redirects_total` - OAuth redirects

**Add to Prometheus scrape config:**
```yaml
- job_name: 'oauth2-proxy'
  static_configs:
  - targets: ['oauth2-proxy-grafana.grafana.svc:4180']
```

## Expanding to Other Services

### Pattern for Protecting Additional Services

1. **Deploy OAuth2 Proxy per service:**
   ```bash
   cp -r apps/oauth2-proxy/grafana-deployment.yaml apps/oauth2-proxy/prometheus-deployment.yaml
   ```

2. **Update configuration:**
   - Change deployment name: `oauth2-proxy-prometheus`
   - Update `--upstream`: Point to Prometheus service
   - Update `--redirect-url`: Use prometheus.local domain
   - Create separate service and sealed secret

3. **Update ingress:**
   ```yaml
   backend:
     service:
       name: oauth2-proxy-prometheus
       port:
         number: 4180
   ```

4. **Add callback URL to GitHub OAuth App:**
   ```
   https://prometheus.local:32742/oauth2/callback
   ```

### Multi-Service Architecture

```
┌────────────────────────────────────────────────────┐
│              Single GitHub OAuth App               │
│  Multiple callback URLs:                           │
│  ├─ https://grafana.local:32742/oauth2/callback    │
│  ├─ https://prometheus.local:32742/oauth2/callback │
│  └─ https://rabbitmq.local:32742/oauth2/callback   │
└────────────────────────────────────────────────────┘
         │
         │ Used by multiple OAuth2 Proxy instances
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  OAuth2 Proxy Instances (one per service)          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │ oauth2-proxy │  │ oauth2-proxy │  │ oauth2   │  │
│  │   -grafana   │  │ -prometheus  │  │ -rabbitmq│  │
│  └──────┬───────┘  └──────┬───────┘  └────┬─────┘  │
│         │                 │                │        │
└─────────┼─────────────────┼────────────────┼────────┘
          │                 │                │
          ▼                 ▼                ▼
    ┌─────────┐       ┌──────────┐    ┌─────────┐
    │ Grafana │       │Prometheus│    │RabbitMQ │
    └─────────┘       └──────────┘    └─────────┘
```

**Benefits:**
- Single GitHub OAuth App for all services
- Per-service access control possible
- Independent OAuth2 Proxy instances (isolated)
- Consistent authentication experience

## Files Reference

```
apps/
└── oauth2-proxy/
    ├── namespace.yaml              ← oauth2-proxy namespace (optional)
    ├── sealed-secret.yaml          ← Encrypted credentials
    ├── grafana-deployment.yaml     ← OAuth2 Proxy for Grafana
    ├── grafana-service.yaml        ← Service exposing OAuth2 Proxy
    └── kustomization.yaml          ← GitOps configuration

apps/grafana/
└── ingress.yaml                    ← Modified to route through OAuth2 Proxy
```

## Related Documentation

- [SEALED-SECRETS.md](SEALED-SECRETS.md) - Secrets management
- [CERT-MANAGER.md](CERT-MANAGER.md) - TLS certificate management
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall cluster architecture

---

**Implemented:** 2026-01-10
**Provider:** GitHub OAuth
**Protected Services:** Grafana (expandable to all services)
**Security:** RSA-4096 encrypted secrets + HTTPS-only cookies
