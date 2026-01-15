# CI/CD Pipeline Documentation

## Overview

This project uses **GitHub Actions** for building container images and **Flux Image Automation** for automatic deployments. This approach was chosen because traditional CI/CD tools like Tekton and Jenkins don't support ARM32 architecture (Raspberry Pi).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CI/CD PIPELINE FLOW                                │
└─────────────────────────────────────────────────────────────────────────┘

  Developer                GitHub                     Kubernetes Cluster
  ┌──────────┐           ┌──────────┐               ┌────────────────────┐
  │          │  git push │          │               │                    │
  │  Commit  │──────────►│  GitHub  │               │  Flux Controllers  │
  │  Code    │           │  Repo    │               │                    │
  │          │           │          │               │  ┌──────────────┐  │
  └──────────┘           └────┬─────┘               │  │ image-       │  │
                              │                      │  │ reflector    │  │
                              │ triggers             │  │ controller   │  │
                              ▼                      │  └──────┬───────┘  │
                        ┌──────────┐                │         │          │
                        │  GitHub  │                │  polls  │  every   │
                        │  Actions │                │  GHCR   │  1 min   │
                        │          │                │         ▼          │
                        │  Build   │                │  ┌──────────────┐  │
                        │  Image   │                │  │ image-       │  │
                        └────┬─────┘                │  │ automation   │  │
                             │                      │  │ controller   │  │
                             │ push                 │  └──────┬───────┘  │
                             ▼                      │         │          │
                        ┌──────────┐                │  updates│          │
                        │  GitHub  │◄───────────────│  deploy-│          │
                        │Container │  watches for   │  ment.  │          │
                        │ Registry │  new tags      │  yaml   │          │
                        │  (GHCR)  │                │         ▼          │
                        └──────────┘                │  ┌──────────────┐  │
                                                    │  │ kustomize-   │  │
                                                    │  │ controller   │  │
                                                    │  │              │  │
                                                    │  │ Deploys new  │  │
                                                    │  │ image to pod │  │
                                                    │  └──────────────┘  │
                                                    └────────────────────┘
```

## Components

### 1. GitHub Actions Workflow

**File:** `.github/workflows/smartbiz-ci.yaml`

The workflow builds multi-architecture Docker images when code changes are pushed.

**Triggers:**
- Push to `main` branch
- Only for specific files (prevents feedback loops):
  - `apps/smartbiz-api/main.py`
  - `apps/smartbiz-api/Dockerfile`
  - `apps/smartbiz-api/requirements.txt`
  - `apps/smartbiz-api/tests/**`
  - `.github/workflows/smartbiz-ci.yaml`

**Build Process:**
1. Checkout repository
2. Calculate version from commit count
3. Set up QEMU for multi-arch builds
4. Set up Docker Buildx
5. Login to GitHub Container Registry
6. Build and push multi-arch image (ARM32, ARM64, AMD64)
7. Generate build summary

**Versioning:**
```bash
VERSION="1.0.${COMMIT_COUNT}"
# Example: 1.0.1329
```

**Platforms Built:**
- `linux/arm/v7` (Raspberry Pi 32-bit)
- `linux/arm64` (Raspberry Pi 64-bit)
- `linux/amd64` (Standard x86_64)

### 2. Flux Image Reflector Controller

**Purpose:** Monitors container registries for new image tags.

**File:** `clusters/my-cluster/flux-system/image-automation.yaml`

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: smartbiz-api
  namespace: flux-system
spec:
  image: ghcr.io/seadavdic/smartbiz-api
  interval: 1m
```

**What it does:**
- Scans `ghcr.io/seadavdic/smartbiz-api` every minute
- Detects new tags (e.g., `1.0.1329`, `1.0.1330`)
- Makes tag information available to other controllers

### 3. Flux Image Policy

**Purpose:** Defines which tags should be selected for deployment.

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: smartbiz-api
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: smartbiz-api
  policy:
    semver:
      range: ">=1.0.0"
```

**Policy:** Selects the highest semantic version >= 1.0.0

### 4. Flux Image Update Automation

**Purpose:** Automatically updates deployment files with new image tags.

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: smartbiz-api
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: Flux Image Automation
        email: flux@raspberrypi-cluster.local
    push:
      branch: main
  update:
    path: ./apps/smartbiz-api
    strategy: Setters
```

**What it does:**
1. When new image is detected by ImagePolicy
2. Updates `deployment.yaml` with new image tag
3. Commits the change to Git
4. Pushes to the `main` branch

### 5. Image Policy Marker in Deployment

**File:** `apps/smartbiz-api/deployment.yaml`

```yaml
containers:
- name: api
  image: ghcr.io/seadavdic/smartbiz-api:1.0.1329 # {"$imagepolicy": "flux-system:smartbiz-api"}
```

The comment `# {"$imagepolicy": "flux-system:smartbiz-api"}` tells Flux which ImagePolicy to use for updating this image tag.

## Complete Flow Example

1. **Developer commits code change:**
   ```bash
   # Edit apps/smartbiz-api/main.py
   git add .
   git commit -m "Add new feature"
   git push
   ```

2. **GitHub Actions triggers:**
   - Workflow starts automatically
   - Builds Docker image for 3 architectures
   - Pushes to `ghcr.io/seadavdic/smartbiz-api:1.0.1330`

3. **Flux Image Reflector detects new tag:**
   - Scans registry every minute
   - Finds `1.0.1330` (higher than current `1.0.1329`)

4. **Flux Image Policy selects new tag:**
   - Evaluates semver policy
   - Selects `1.0.1330` as latest valid version

5. **Flux Image Update Automation updates deployment:**
   - Edits `apps/smartbiz-api/deployment.yaml`
   - Changes image tag to `1.0.1330`
   - Commits: "Update SmartBiz API image to ghcr.io/seadavdic/smartbiz-api:1.0.1330"
   - Pushes to GitHub

6. **Flux Kustomize Controller deploys:**
   - Detects changed deployment.yaml
   - Applies new deployment to cluster
   - Kubernetes pulls new image and restarts pod

**Total time: ~3-5 minutes** (build: ~2-3 min, detection: ~1 min, deploy: ~1 min)

## Preventing Feedback Loops

### The Problem

Without proper configuration, a feedback loop can occur:
1. Developer pushes code
2. GitHub Actions builds image
3. Flux updates deployment.yaml
4. Flux pushes to Git
5. GitHub Actions triggers again (sees push to main)
6. Builds another image...
7. Loop continues!

### The Solution

The workflow only triggers on specific files:

```yaml
on:
  push:
    branches:
      - main
    paths:
      # Only trigger on actual code changes, not deployment.yaml
      - 'apps/smartbiz-api/main.py'
      - 'apps/smartbiz-api/Dockerfile'
      - 'apps/smartbiz-api/requirements.txt'
      - 'apps/smartbiz-api/tests/**'
      - '.github/workflows/smartbiz-ci.yaml'
```

When Flux updates `deployment.yaml`, GitHub Actions ignores it because that file is not in the paths list.

## GitHub Container Registry Setup

### Making the Package Public

By default, GHCR packages are private. To allow Kubernetes to pull without authentication:

1. Go to GitHub → Packages → smartbiz-api
2. Package settings → Change visibility → Public

### Workflow Permissions

The workflow needs `packages: write` permission:

```yaml
permissions:
  contents: read
  packages: write
```

## Flux SSH Key Setup

Flux needs write access to push commits back to GitHub.

### Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "flux@raspberrypi-cluster" -f flux-key
```

### Add Deploy Key to GitHub

1. Go to GitHub → Repository → Settings → Deploy keys
2. Add new key
3. Paste the public key (`flux-key.pub`)
4. Check "Allow write access"

### Update Flux Secret

```bash
kubectl create secret generic flux-system \
  --from-file=identity=flux-key \
  --from-file=identity.pub=flux-key.pub \
  --from-literal=known_hosts="$(ssh-keyscan github.com)" \
  -n flux-system \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Verification Commands

### Check Image Repository Status

```bash
kubectl get imagerepository -n flux-system
# NAME          LAST SCAN              TAGS
# smartbiz-api  2026-01-15T12:00:00Z   15
```

### Check Image Policy

```bash
kubectl get imagepolicy -n flux-system
# NAME          LATESTIMAGE
# smartbiz-api  ghcr.io/seadavdic/smartbiz-api:1.0.1330
```

### Check Image Update Automation

```bash
kubectl get imageupdateautomation -n flux-system
# NAME          LAST RUN               SUSPENDED
# smartbiz-api  2026-01-15T12:01:00Z   False
```

### View Recent Image Updates

```bash
kubectl describe imageupdateautomation smartbiz-api -n flux-system
```

### Check GitHub Actions

```bash
gh run list --workflow=smartbiz-ci.yaml
```

## Troubleshooting

### Image not updating?

1. **Check ImageRepository:**
   ```bash
   kubectl describe imagerepository smartbiz-api -n flux-system
   ```
   Look for errors in Events section.

2. **Check ImagePolicy:**
   ```bash
   kubectl describe imagepolicy smartbiz-api -n flux-system
   ```
   Verify the selected image is correct.

3. **Check Git push permissions:**
   ```bash
   kubectl logs -n flux-system deployment/image-automation-controller
   ```
   Look for authentication errors.

### Build failing?

1. **Check GitHub Actions logs:**
   - Go to repository → Actions → Select workflow run
   - View logs for each step

2. **Common issues:**
   - Dockerfile syntax errors
   - Missing dependencies
   - GHCR authentication issues

### Deployment not updating?

1. **Check Flux reconciliation:**
   ```bash
   flux reconcile kustomization apps --with-source
   ```

2. **Check deployment status:**
   ```bash
   kubectl get deployment smartbiz-api -n smartbiz
   kubectl describe deployment smartbiz-api -n smartbiz
   ```

## Adding CI/CD for New Applications

To add CI/CD for a new application:

1. **Create GitHub Actions workflow:**
   ```yaml
   # .github/workflows/myapp-ci.yaml
   name: MyApp CI/CD
   on:
     push:
       branches: [main]
       paths:
         - 'apps/myapp/**'
         - '.github/workflows/myapp-ci.yaml'
   # ... (similar to smartbiz-ci.yaml)
   ```

2. **Add ImageRepository:**
   ```yaml
   apiVersion: image.toolkit.fluxcd.io/v1beta2
   kind: ImageRepository
   metadata:
     name: myapp
     namespace: flux-system
   spec:
     image: ghcr.io/username/myapp
     interval: 1m
   ```

3. **Add ImagePolicy:**
   ```yaml
   apiVersion: image.toolkit.fluxcd.io/v1beta2
   kind: ImagePolicy
   metadata:
     name: myapp
     namespace: flux-system
   spec:
     imageRepositoryRef:
       name: myapp
     policy:
       semver:
         range: ">=1.0.0"
   ```

4. **Add image policy marker to deployment:**
   ```yaml
   image: ghcr.io/username/myapp:1.0.0 # {"$imagepolicy": "flux-system:myapp"}
   ```

5. **Update ImageUpdateAutomation path (or create separate one):**
   ```yaml
   update:
     path: ./apps/myapp
   ```

## Why Not Tekton or Jenkins?

### Tekton

Tekton requires running CI/CD tasks as Kubernetes pods. Unfortunately:
- Tekton images don't support ARM32 architecture
- Pods fail with "no match for platform in manifest"

### Jenkins

Jenkins requires either:
- Official Jenkins image (no ARM32 support)
- Community ARM32 images (outdated, broken, or unmaintained)

### GitHub Actions Advantages

- Runs on GitHub's infrastructure (not on cluster)
- Native multi-architecture build support (QEMU + buildx)
- No ARM32 compatibility issues
- Free for public repositories
- Integrates with GitHub Container Registry

## Related Documentation

- [SMARTBIZ.md](SMARTBIZ.md) - SmartBiz application documentation
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall cluster architecture
- [SEALED-SECRETS.md](SEALED-SECRETS.md) - Secrets management

---

**Implemented:** 2026-01-15
**Status:** ✅ Fully Operational
**Components:** GitHub Actions + Flux Image Automation
