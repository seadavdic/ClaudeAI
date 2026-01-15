# Tekton CI/CD Pipelines

> **⚠️ IMPORTANT: Tekton does NOT support ARM32 (Raspberry Pi)**
>
> Tekton container images are not available for ARM32 architecture. When deployed on a Raspberry Pi cluster, pods fail with:
> ```
> no match for platform in manifest: not found
> ```
>
> **Recommended Alternative:** Use [GitHub Actions + Flux Image Automation](CICD-PIPELINE.md) instead.
> This approach builds images on GitHub's infrastructure and uses Flux to automatically deploy new versions.

---

## Overview (Reference Only)

Tekton is a cloud-native CI/CD system that runs directly on Kubernetes. It provides building blocks (Tasks, Pipelines, Triggers) to create automated workflows for building, testing, and deploying applications.

**Note:** The information below is kept for reference purposes. This solution was NOT implemented due to ARM32 incompatibility.

## Why Tekton?

```
Traditional CI/CD (Jenkins, GitLab CI, etc.):
├─ Runs on dedicated servers
├─ Configuration in scripts or YAML
├─ Separate from Kubernetes
└─ Requires additional infrastructure

Tekton (Cloud-Native CI/CD):
├─ Runs as Kubernetes pods
├─ Defined as Kubernetes resources
├─ Managed via GitOps (Flux CD)
├─ Uses cluster resources efficiently
└─ No separate infrastructure needed
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TEKTON ARCHITECTURE                              │
└─────────────────────────────────────────────────────────────────────────┘

Components:

┌──────────────────────────────────────────────────────────────────┐
│  Tekton Pipelines (Core)                                        │
│  ├─ tekton-pipelines-controller (manages pipeline execution)    │
│  ├─ tekton-pipelines-webhook (validates resources)              │
│  └─ Provides: Tasks, Pipelines, TaskRuns, PipelineRuns          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  Tekton Dashboard (UI)                                           │
│  ├─ Web interface for viewing pipelines                         │
│  ├─ Access: https://tekton.local:32742                          │
│  └─ View pipeline runs, logs, and status                        │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  Tekton Triggers (Optional)                                      │
│  ├─ Automate pipeline execution on events                       │
│  ├─ GitHub webhooks → auto-run pipeline on push                 │
│  └─ EventListeners, Triggers, TriggerBindings                   │
└──────────────────────────────────────────────────────────────────┘
```

## Core Concepts

### 1. Task
A Task is a reusable unit of work with one or more steps.

**Example: Run Python Tests**
```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: python-test
spec:
  steps:
    - name: run-tests
      image: python:3.11-slim
      script: |
        pip install pytest
        pytest tests/
```

Think of a Task like a function in programming - it does one specific thing.

### 2. Pipeline
A Pipeline chains multiple Tasks together into a workflow.

**Example: CI/CD Pipeline**
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: smartbiz-cicd
spec:
  tasks:
    - name: clone-repo
      taskRef:
        name: git-clone
    - name: run-tests
      taskRef:
        name: python-test
      runAfter:
        - clone-repo
    - name: build-image
      taskRef:
        name: build-image
      runAfter:
        - run-tests
```

Think of a Pipeline like a recipe - it defines the steps in order.

### 3. TaskRun / PipelineRun
Executes a Task or Pipeline (like running a function).

**Example: Run the Pipeline**
```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: smartbiz-cicd-run-001
spec:
  pipelineRef:
    name: smartbiz-cicd
  params:
    - name: git-url
      value: https://github.com/user/repo.git
```

### 4. Workspaces
Shared storage between Tasks in a Pipeline.

```
Pipeline Execution Flow:

Task 1: Clone Repo
  ↓ (writes to workspace)
Workspace (PVC storage)
  ↓ (reads from workspace)
Task 2: Run Tests
  ↓ (reads from workspace)
Task 3: Build Image
```

## Installation

### Step 1: Install Tekton Pipelines

```bash
# Apply Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.55.0/release.yaml

# Verify installation
kubectl get pods -n tekton-pipelines

# Expected output:
# NAME                                          READY   STATUS    RESTARTS   AGE
# tekton-pipelines-controller-...               1/1     Running   0          1m
# tekton-pipelines-webhook-...                  1/1     Running   0          1m
```

### Step 2: Install Tekton Dashboard (Optional)

```bash
# Apply Tekton Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/previous/v0.43.0/release.yaml

# Verify dashboard
kubectl get pods -n tekton-pipelines

# Expected additional pod:
# tekton-dashboard-...                          1/1     Running   0          1m
```

### Step 3: Deploy Resources via Flux

```bash
# Commit Tekton manifests
git add apps/tekton/
git commit -m "Add Tekton CI/CD pipelines"
git push

# Flux will automatically apply resources
flux reconcile kustomization apps --with-source

# Verify resources
kubectl get tasks,pipelines,pipelineruns -n tekton-pipelines
```

### Step 4: Add to hosts file

```
# Windows: C:\Windows\System32\drivers\etc\hosts
# Linux/Mac: /etc/hosts

<cluster-ip> tekton.local
```

## SmartBiz CI/CD Pipeline

The included SmartBiz pipeline provides a complete CI/CD workflow:

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SMARTBIZ CI/CD PIPELINE FLOW                         │
└─────────────────────────────────────────────────────────────────────────┘

1. Fetch Repository (git-clone task)
   ├─ Clones GitHub repository
   ├─ Checks out specified branch/tag
   └─ Writes to shared workspace (PVC)

2. Run Tests (python-test task)
   ├─ Installs Python dependencies
   ├─ Runs pytest
   ├─ Generates coverage report
   └─ Fails pipeline if tests fail

3. Build Image (build-image task)
   ├─ Uses Kaniko (no Docker daemon needed)
   ├─ Builds container image
   ├─ Pushes to registry (Docker Hub)
   └─ Outputs image digest

4. Deploy to Cluster (deploy-to-kubernetes task)
   ├─ Updates deployment with new image
   ├─ Waits for rollout to complete
   └─ Verifies all pods are healthy

5. Finally: Notify Status
   ├─ Sends notification (Slack/Telegram)
   └─ Logs pipeline completion
```

### Running the Pipeline

#### Manual Execution

```bash
# Create a PipelineRun
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: smartbiz-cicd-run-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: smartbiz-cicd
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: tekton-workspace-pvc
  params:
    - name: git-url
      value: https://github.com/seadavdic/ClaudeAI.git
    - name: git-revision
      value: main
    - name: image-name
      value: docker.io/seadavdic/smartbiz-api
    - name: image-tag
      value: v1.0.0
EOF

# Watch the pipeline run
kubectl get pipelinerun -n tekton-pipelines -w

# View logs
tkn pipelinerun logs <pipelinerun-name> -f -n tekton-pipelines

# Or use Tekton Dashboard: https://tekton.local:32742
```

#### Using Tekton CLI (tkn)

```bash
# Install tkn CLI
# Linux:
curl -LO https://github.com/tektoncd/cli/releases/download/v0.33.0/tkn_0.33.0_Linux_x86_64.tar.gz
tar xvzf tkn_0.33.0_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn

# Windows:
choco install tektoncd-cli

# Run pipeline
tkn pipeline start smartbiz-cicd -n tekton-pipelines \
  --param git-url=https://github.com/seadavdic/ClaudeAI.git \
  --param git-revision=main \
  --param image-tag=v1.0.1 \
  --workspace name=shared-workspace,claimName=tekton-workspace-pvc \
  --showlog

# List pipeline runs
tkn pipelinerun list -n tekton-pipelines

# View logs
tkn pipelinerun logs smartbiz-cicd-run-001 -n tekton-pipelines
```

## Docker Registry Authentication

To push images to Docker Hub, create credentials:

```bash
# Create Docker Hub secret
kubectl create secret docker-registry docker-credentials \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=YOUR_EMAIL \
  -n tekton-pipelines

# Or use sealed secrets (recommended)
kubectl create secret docker-registry docker-credentials \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=YOUR_EMAIL \
  --dry-run=client -o yaml | \
  kubeseal --format=yaml > apps/tekton/docker-credentials-sealed.yaml
```

Update the PipelineRun to use credentials:

```yaml
spec:
  workspaces:
    - name: docker-credentials
      secret:
        secretName: docker-credentials
```

## Automated Triggers (Webhooks)

### Install Tekton Triggers

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.25.0/release.yaml
```

### Create EventListener

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
  namespace: tekton-pipelines
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - name: github-push
      interceptors:
        - ref:
            name: github
          params:
            - name: secretRef
              value:
                secretName: github-webhook-secret
                secretKey: secret
            - name: eventTypes
              value: ["push"]
      bindings:
        - ref: github-binding
      template:
        ref: smartbiz-trigger-template
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-binding
  namespace: tekton-pipelines
spec:
  params:
    - name: git-revision
      value: $(body.head_commit.id)
    - name: git-url
      value: $(body.repository.clone_url)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: smartbiz-trigger-template
  namespace: tekton-pipelines
spec:
  params:
    - name: git-revision
    - name: git-url
  resourcetemplates:
    - apiVersion: tekton.dev/v1beta1
      kind: PipelineRun
      metadata:
        generateName: smartbiz-cicd-run-
      spec:
        pipelineRef:
          name: smartbiz-cicd
        params:
          - name: git-url
            value: $(tt.params.git-url)
          - name: git-revision
            value: $(tt.params.git-revision)
        workspaces:
          - name: shared-workspace
            persistentVolumeClaim:
              claimName: tekton-workspace-pvc
```

### GitHub Webhook Setup

1. Go to your GitHub repository settings
2. Navigate to **Webhooks** → **Add webhook**
3. **Payload URL**: `https://tekton.local:32742/hooks/github-listener`
4. **Content type**: `application/json`
5. **Secret**: Your webhook secret
6. **Events**: Select "Just the push event"
7. Click **Add webhook**

Now every push to main branch will automatically trigger the pipeline!

## Accessing the Dashboard

### Local Access (HTTPS)
```
URL: https://tekton.local:32742
Authentication: None (add OAuth2 if needed)
CA Trust: See docs/CERT-MANAGER.md
```

### Dashboard Features
```
┌──────────────────────────────────────────────────────────────┐
│  Tekton Dashboard                                            │
│                                                              │
│  Navigation:                                                 │
│  ├─ Pipelines (view all defined pipelines)                  │
│  ├─ PipelineRuns (execution history)                        │
│  ├─ Tasks (reusable task definitions)                       │
│  ├─ TaskRuns (task execution logs)                          │
│  └─ Triggers (webhook configurations)                       │
│                                                              │
│  For each PipelineRun:                                       │
│  ├─ Status (Running, Succeeded, Failed)                     │
│  ├─ Duration                                                 │
│  ├─ Task-by-task progress                                   │
│  ├─ Real-time logs                                          │
│  └─ YAML definitions                                        │
└──────────────────────────────────────────────────────────────┘
```

## Creating Custom Pipelines

### Example: Deploy a New Application

```yaml
# 1. Create a Task for your specific needs
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: npm-build
  namespace: tekton-pipelines
spec:
  workspaces:
    - name: source
  steps:
    - name: install-and-build
      image: node:18-alpine
      workingDir: $(workspaces.source.path)
      script: |
        npm install
        npm run build

# 2. Create a Pipeline
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: frontend-cicd
  namespace: tekton-pipelines
spec:
  workspaces:
    - name: shared-workspace
  tasks:
    - name: fetch-repo
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
    - name: build
      taskRef:
        name: npm-build
      runAfter: [fetch-repo]
      workspaces:
        - name: source
          workspace: shared-workspace
    - name: build-image
      taskRef:
        name: build-image
      runAfter: [build]
      workspaces:
        - name: source
          workspace: shared-workspace

# 3. Run the Pipeline
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: frontend-cicd-run-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: frontend-cicd
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: tekton-workspace-pvc
EOF
```

## Monitoring and Observability

### Prometheus Metrics

Tekton exposes Prometheus metrics:

```yaml
# Add to Prometheus scrape config
- job_name: 'tekton-pipelines'
  static_configs:
    - targets: ['tekton-pipelines-controller.tekton-pipelines.svc:9090']

# Available metrics:
# - tekton_pipelines_controller_pipelinerun_duration_seconds
# - tekton_pipelines_controller_pipelinerun_count
# - tekton_pipelines_controller_taskrun_duration_seconds
# - tekton_pipelines_controller_taskrun_count
```

### Grafana Dashboard

Import Tekton dashboard JSON (ID: 12963) or create custom:

```
Panels:
├─ Pipeline Success Rate
├─ Average Pipeline Duration
├─ Pipeline Runs Over Time
├─ Failed Pipelines (last 24h)
├─ Task Duration by Type
└─ Active Pipeline Runs
```

### Logs

```bash
# View all PipelineRun logs
tkn pipelinerun logs -n tekton-pipelines

# View specific PipelineRun
tkn pipelinerun logs smartbiz-cicd-run-001 -n tekton-pipelines

# Follow logs in real-time
tkn pipelinerun logs smartbiz-cicd-run-001 -f -n tekton-pipelines

# View Task logs
tkn taskrun logs <taskrun-name> -n tekton-pipelines
```

## Troubleshooting

### Issue: Pipeline fails immediately

**Check:**
```bash
# View PipelineRun status
kubectl get pipelinerun <name> -n tekton-pipelines -o yaml

# Check pod status
kubectl get pods -n tekton-pipelines | grep <pipelinerun-name>

# View pod logs
kubectl logs <pod-name> -n tekton-pipelines
```

### Issue: Image build fails

**Common causes:**
- Missing Docker credentials
- Incorrect Dockerfile path
- Network issues (pulling base images)

**Fix:**
```bash
# Check Kaniko logs
kubectl logs <build-image-pod> -n tekton-pipelines

# Verify Docker credentials
kubectl get secret docker-credentials -n tekton-pipelines
```

### Issue: Deployment step fails

**Common causes:**
- Insufficient RBAC permissions
- Invalid deployment name/namespace
- Image pull errors

**Fix:**
```bash
# Check ServiceAccount permissions
kubectl get clusterrolebinding tekton-pipeline-deployer -o yaml

# Verify deployment exists
kubectl get deployment <name> -n <namespace>

# Check image pull secrets
kubectl get pods -n <namespace>
```

### Issue: Workspace PVC not mounting

**Fix:**
```bash
# Check PVC status
kubectl get pvc tekton-workspace-pvc -n tekton-pipelines

# Describe PVC for events
kubectl describe pvc tekton-workspace-pvc -n tekton-pipelines

# If using local-path storage, verify:
kubectl get storageclass
```

## Best Practices

### 1. Parameterize Pipelines
```yaml
# Good: Flexible parameters
params:
  - name: image-tag
    type: string
  - name: environment
    type: string
    default: staging

# Bad: Hardcoded values
image: myapp:latest  # Not flexible
```

### 2. Use Workspaces for Sharing Data
```yaml
# Good: Shared workspace
workspaces:
  - name: source

# Bad: Copying artifacts between tasks manually
```

### 3. Add Resource Limits
```yaml
steps:
  - name: build
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 2Gi
        cpu: 1000m
```

### 4. Implement Proper Error Handling
```yaml
steps:
  - name: test
    onError: continue  # Continue even if this fails
    script: |
      npm test || echo "Tests failed, continuing anyway"
```

### 5. Clean Up Old PipelineRuns
```yaml
# Automatic cleanup
spec:
  timeouts:
    pipeline: "1h"
  # Or use a CronJob to delete old runs:
  # kubectl delete pipelinerun --field-selector status.completionTime<2024-01-01 -n tekton-pipelines
```

## Integration with Existing Tools

### With Flux CD (GitOps)
```
Git Push → Flux detects change → Applies Pipeline/Task changes
Manual: kubectl create pipelinerun → Pipeline executes → Deployment updated
Auto: GitHub Webhook → Trigger → Pipeline executes → Deployment updated
```

### With Grafana
- Create dashboard for pipeline metrics
- Alert on failed pipelines
- Monitor pipeline duration trends

### With Slack/Telegram
```yaml
finally:
  - name: notify
    taskSpec:
      steps:
        - name: send-notification
          image: curlimages/curl
          script: |
            curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
              -d '{"text": "Pipeline $(context.pipelineRun.name) completed with status $(tasks.status)"}'
```

## Files Reference

```
apps/tekton/
├── namespace.yaml                              ← tekton-pipelines namespace
├── install.yaml                                ← Installation instructions
├── dashboard-ingress.yaml                      ← Web UI access
├── kustomization.yaml                          ← Flux configuration
└── smartbiz-pipeline/
    ├── 01-task-git-clone.yaml                 ← Clone repository task
    ├── 02-task-python-test.yaml               ← Run Python tests task
    ├── 03-task-build-image.yaml               ← Build Docker image with Kaniko
    ├── 04-task-deploy-k8s.yaml                ← Deploy to Kubernetes task
    ├── 05-pipeline-smartbiz.yaml              ← Complete CI/CD pipeline
    ├── 06-workspace-pvc.yaml                  ← Shared storage for tasks
    └── 07-pipelinerun-example.yaml            ← Example execution + RBAC
```

## Related Documentation

- [CICD-PIPELINE.md](CICD-PIPELINE.md) - **RECOMMENDED: GitHub Actions + Flux Image Automation**
- [SEALED-SECRETS.md](SEALED-SECRETS.md) - Secure credentials for registry
- [CERT-MANAGER.md](CERT-MANAGER.md) - TLS for Dashboard
- [OAUTH2-GITHUB.md](OAUTH2-GITHUB.md) - Protect Dashboard with OAuth2
- [GRAFANA-DASHBOARDS.md](GRAFANA-DASHBOARDS.md) - Monitoring dashboards

---

**Status:** ❌ NOT IMPLEMENTED (ARM32 incompatible)
**Reason:** Tekton images do not support ARM32 architecture
**Alternative:** See [CICD-PIPELINE.md](CICD-PIPELINE.md) for working solution
**Last Updated:** 2026-01-15
