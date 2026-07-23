# Task Manager API — Kubernetes Learning Project

A simple Task Management REST API built with NestJS, designed to learn Kubernetes step-by-step on Docker Desktop's single-node cluster.

## API Endpoints

| Method | Path         | Description                              |
| ------ | ------------ | ---------------------------------------- |
| GET    | `/`          | Hello World                              |
| GET    | `/health`    | Health check (status, timestamp, uptime) |
| GET    | `/tasks`     | List all tasks                           |
| POST   | `/tasks`     | Create a new task                        |
| GET    | `/tasks/:id` | Get a single task                        |
| PUT    | `/tasks/:id` | Update a task                            |
| DELETE | `/tasks/:id` | Delete a task                            |

### Sample Requests

```bash
# Create a task
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Learn Kubernetes", "description": "Master pods and deployments"}'

# List all tasks
curl http://localhost:3000/tasks

# Health check
curl http://localhost:3000/health
```

## Prerequisites

| Tool           | Minimum Version | Check Command                 |
| -------------- | --------------- | ----------------------------- |
| Node.js        | 22.x            | `node --version`              |
| npm            | 10.x            | `npm --version`               |
| Docker Desktop | 29.x            | `docker --version`            |
| kubectl        | 1.29+           | `kubectl version --client`    |
| GitHub Account | —               | (for GHCR container registry) |

## Project Structure

```
nestjs-kubernetes-learning/
├── src/
│   ├── app.module.ts          # Root application module
│   ├── app.controller.ts      # GET / and GET /health
│   ├── app.service.ts         # Business logic for routes
│   ├── main.ts                # Entry point (ValidationPipe, port)
│   └── tasks/
│       ├── tasks.module.ts    # Tasks feature module
│       ├── tasks.controller.ts # CRUD endpoints
│       ├── tasks.service.ts   # In-memory data store
│       ├── task.interface.ts  # Task data shape
│       └── dto/
│           ├── create-task.dto.ts
│           └── update-task.dto.ts
├── kubernetes/                # All Kubernetes manifests
│   ├── namespace.yaml         # Logical isolation (task-manager)
│   ├── configmap.yaml         # Non-sensitive configuration
│   ├── secret.yaml            # Sensitive data (passwords, tokens)
│   ├── deployment.yaml        # Pods, ReplicaSets, probes, rolling updates
│   ├── service.yaml           # ClusterIP + NodePort services
│   ├── ingress.yaml           # External HTTP routing
│   └── imagepullsecret.yaml   # GHCR authentication guide (template only)
├── Dockerfile                 # Multi-stage production build
├── .dockerignore              # Excludes from Docker build context
├── .gitignore                 # Excludes from Git
└── package.json
```

## Local Development (No Docker)

```bash
# Install dependencies
npm install

# Start in development mode (hot-reload)
npm run start:dev

# OR: Build and run production
npm run build
node dist/main
```

The app runs on [http://localhost:3000](http://localhost:3000).

---

## Kubernetes Deployment Guide

This guide walks through deploying the NestJS application on Kubernetes using Docker Desktop.

### 1. Login to GitHub Container Registry

```bash
docker login ghcr.io -u marufrahmanlive
```

> You'll be prompted for your GitHub Personal Access Token (PAT) with `read:packages`, `write:packages`, and `delete:packages` scopes.

### 2. Build the Docker Image

```bash
# Option A: Build directly with Docker
docker build -t ghcr.io/marufrahmanlive/task-manager:latest .

# Option B: Build using Docker Compose
docker compose build --no-cache
```

### 3. Push to GHCR

```bash
# Option A: Push directly with Docker
docker push ghcr.io/marufrahmanlive/task-manager:latest

# Option B: Push using Docker Compose
docker compose push
```

### 4. Install Ingress Controller

Docker Desktop doesn't include an Ingress Controller by default. Install nginx-ingress:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 5. Create Namespace

```bash
kubectl apply -f kubernetes/namespace.yaml
```

### 6. Create Image Pull Secret for GHCR

Replace `<github_username>`, `<CR_PAT>`, and `<email>` with your actual GitHub credentials:

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace=task-manager \
  --docker-server=ghcr.io \
  --docker-username=<github_username> \
  --docker-password=<CR_PAT> \
  --docker-email=<email>
```

Verify the secret was created:

```bash
kubectl get secrets --namespace task-manager
```

### 7. Deploy All Resources

```bash
# Apply all Kubernetes manifests in the kubernetes/ directory
kubectl apply -f kubernetes/

# Check that the pods are running
kubectl get pods --namespace task-manager
```

### 8. Delete All Resources

To tear down everything under the namespace:

```bash
kubectl delete namespace task-manager
```

---

## Automated Deployment with GitHub Actions

This repository includes a **self-hosted** GitHub Actions workflow at `.github/workflows/deploy.yml` that automates the full CI/CD pipeline on your local PC.

### Pipeline Overview

```
Push to main → Tests → Auto-tag (bump semver) → Build & Push (docker compose) → Deploy to K8s
```

The workflow consists of **4 jobs**:

| Job                | Runner        | Trigger     | Description                                                                                        |
| ------------------ | ------------- | ----------- | -------------------------------------------------------------------------------------------------- |
| **test**           | ubuntu-latest | Branch push | Runs `npm run test` to validate code                                                               |
| **auto-tag**       | ubuntu-latest | Branch push | Reads the last semver tag, bumps the patch, pushes e.g. `v1.0.3`                                   |
| **build-and-push** | ubuntu-latest | Tag push    | Builds image via `docker compose build --no-cache`, pushes versioned tag + `:latest` to GHCR       |
| **deploy-to-k8s**  | self-hosted   | Tag push    | Applies all Kubernetes manifests, updates deployment to the new versioned image, waits for rollout |

### Setting Up the Self-Hosted Runner

1. In your GitHub repository, go to **Settings → Actions → Runners → New self-hosted runner**
2. Follow the instructions to download and configure the runner on your local PC
3. Ensure Docker Desktop with Kubernetes is running before starting the runner
4. Set `kubectl` context to `docker-desktop`:
   ```bash
   kubectl config use-context docker-desktop
   ```

### Required GitHub Secret

The workflow uses a **single secret** named `GH_PAT` for all authentication needs.

1. Create a GitHub Personal Access Token (classic) with scopes:
   - `repo` (for pushing auto-created version tags)
   - `write:packages` (for pushing Docker images to GHCR)
   - `read:packages` (for reading GHCR packages)
   - `delete:packages` (for managing GHCR packages)
2. Go to **Settings → Secrets and variables → Actions → New repository secret**
3. Name: `GH_PAT`, Value: your personal access token

### Triggers

- **Push to `main` or `master` branch** — triggers tests → auto-tag → build-and-push → deploy
- **Tag push (`v*.*.*`)** — triggers build-and-push → deploy directly (for manual releases)
- **Manual tag push** — `git tag -a v1.0.0 -m "release" && git push origin v1.0.0`

### How Auto-Tagging Works

Every push to `main` automatically:

1. Finds the most recent semver tag (e.g., `v1.0.2`)
2. Bumps the patch version (e.g., `v1.0.3`)
3. Creates and pushes the new tag to the repository
4. The tag push triggers the build-and-push + deploy jobs

### Docker Compose Integration

The `docker-compose.yml` uses the `IMAGE_TAG` environment variable for dynamic tagging:

```yaml
image: ${IMAGE_TAG:-ghcr.io/marufrahmanlive/task-manager:latest}
```

- In CI/CD, `IMAGE_TAG` is set to the versioned image (e.g., `ghcr.io/marufrahmanlive/task-manager:1.0.3`)
- Locally, it falls back to `ghcr.io/marufrahmanlive/task-manager:latest`

---

## Kubernetes Concepts Covered

Each manifest file in `kubernetes/` contains extensive inline documentation. Topics covered:

| #   | Topic                                      | File                              |
| --- | ------------------------------------------ | --------------------------------- |
| 1   | Docker Image (multi-stage build)           | `Dockerfile`                      |
| 2   | GitHub Container Registry (GHCR)           | This README                       |
| 3   | Private Registry Auth (`imagePullSecrets`) | `kubernetes/imagepullsecret.yaml` |
| 4   | Namespace                                  | `kubernetes/namespace.yaml`       |
| 5   | Pod                                        | `kubernetes/deployment.yaml`      |
| 6   | Labels & Selectors                         | All manifests                     |
| 7   | Deployment & ReplicaSet                    | `kubernetes/deployment.yaml`      |
| 8   | Service (ClusterIP + NodePort)             | `kubernetes/service.yaml`         |
| 9   | Load Balancing                             | `kubernetes/service.yaml`         |
| 10  | Ingress                                    | `kubernetes/ingress.yaml`         |
| 11  | ConfigMap                                  | `kubernetes/configmap.yaml`       |
| 12  | Secret                                     | `kubernetes/secret.yaml`          |
| 13  | Environment Variables                      | `kubernetes/deployment.yaml`      |
| 14  | Liveness & Readiness Probes                | `kubernetes/deployment.yaml`      |
| 15  | Rolling Updates                            | `kubernetes/deployment.yaml`      |
| 16  | Resource Requests & Limits                 | `kubernetes/deployment.yaml`      |

---

## Accessing the Application

After deployment, the application is available through the Ingress controller at:

```bash
curl http://localhost/health
curl http://localhost/tasks
```

For quick testing without Ingress, use port-forwarding:

```bash
kubectl port-forward -n task-manager svc/task-manager-service 3000:3000

# In another terminal:
curl http://localhost:3000/health
```

---

## Common Troubleshooting

### ImagePullBackOff Error

**Cause:** Kubernetes cannot pull the image from GHCR.\
**Fix:**

1. Verify the image exists: `docker pull ghcr.io/marufrahmanlive/task-manager:latest`
2. Check the secret exists: `kubectl get secret ghcr-secret -n task-manager`
3. Recreate the secret with correct credentials (Step 6)
4. Ensure the GHCR package is private for `imagePullSecrets` to work, or public to skip authentication

### CrashLoopBackOff Error

**Cause:** The container starts but immediately crashes.\
**Fix:**

1. Check logs: `kubectl logs -n task-manager -l app=task-manager`
2. Check if the port is already in use
3. Verify environment variables: `kubectl describe pod -n task-manager`

### Pending Pods

**Cause:** Not enough resources on the node.\
**Fix:**

1. Check node resources: `kubectl describe node docker-desktop`
2. Reduce resource requests in `deployment.yaml`

---

## Future Additions (Coming Soon)

- [ ] MongoDB (PersistentVolume, PersistentVolumeClaim, StatefulSet)
- [ ] Redis (caching layer)
- [ ] RabbitMQ (message queue for async task processing)
- [ ] Horizontal Pod Autoscaler (HPA)
