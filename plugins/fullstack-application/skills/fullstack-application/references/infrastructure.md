# Infrastructure

## Dockerfiles

Both Dockerfiles use multi-stage builds. Production images contain no dev dependencies, source files, or secrets.

### Choosing the production base image

| Target | API Base Image | Why |
|--------|---------------|-----|
| **AWS ECS/EKS** | `gcr.io/distroless/nodejs20-debian12` | Minimal attack surface (~60MB), health checks handled by orchestrator |
| **Self-hosted Docker Compose** | `node:20-alpine` | Needs shell for `wget` health checks, debugging access |

When using distroless, the container has no shell — `HEALTHCHECK CMD` with shell form won't work, and you can't `docker exec` into it for debugging. For self-hosted deployments where you're managing containers directly, `node:20-alpine` is the practical choice.

### `infrastructure/docker/api.Dockerfile`

The example below uses distroless (for AWS/K8s). For self-hosted Docker Compose, replace the production stage with `node:20-alpine` and add a non-root user.

```dockerfile
# ---- Build Stage ----
FROM node:20-alpine AS builder
WORKDIR /app

# Install pnpm via Corepack (pinned version for reproducibility)
RUN corepack enable && corepack prepare pnpm@9 --activate

# Copy manifest files first to maximize layer cache hits
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY packages/config/package.json ./packages/config/
COPY packages/database/package.json ./packages/database/
COPY packages/shared/package.json ./packages/shared/
COPY apps/api/package.json ./apps/api/

RUN pnpm install --frozen-lockfile

# Copy source after deps are installed (separate layer)
COPY packages/ ./packages/
COPY apps/api/ ./apps/api/

# Generate Prisma client and build
RUN pnpm --filter @myapp/database exec prisma generate
RUN pnpm --filter api build

# ---- Production Stage (distroless) ----
# No shell, no package manager — minimal attack surface
FROM gcr.io/distroless/nodejs20-debian12 AS runner
WORKDIR /app

COPY --from=builder /app/apps/api/dist ./apps/api/dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages/database/prisma ./packages/database/prisma
COPY --from=builder /app/package.json ./

# distroless has a built-in nonroot user (uid 65532)
USER nonroot

EXPOSE 3001
# Note: distroless has no shell, so HEALTHCHECK CMD must use the array form
# The health check is handled at the orchestrator level (ECS/K8s) instead
CMD ["apps/api/dist/main.js"]
```

For debugging in development, swap `gcr.io/distroless/nodejs20-debian12` for `gcr.io/distroless/nodejs20-debian12:debug` — the `:debug` tag adds a busybox shell (`/busybox/sh`) for inspection.

### `infrastructure/docker/web.Dockerfile`

```dockerfile
# ---- Build Stage ----
FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9 --activate

COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY packages/config/package.json ./packages/config/
COPY packages/shared/package.json ./packages/shared/
COPY apps/web/package.json ./apps/web/

RUN pnpm install --frozen-lockfile

COPY packages/ ./packages/
COPY apps/web/ ./apps/web/

# Inject the API URL at build time (Vite bakes it into the bundle)
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

RUN pnpm --filter web build

# ---- Production Stage (nginx) ----
FROM nginx:1.27-alpine AS runner

COPY --from=builder /app/apps/web/dist /usr/share/nginx/html
COPY infrastructure/docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -qO- http://localhost/health || exit 1
```

### `infrastructure/docker/nginx.conf`

```nginx
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;

  # React Router — serve index.html for all non-file routes
  location / {
    try_files $uri $uri/ /index.html;
  }

  # Nginx health check for containers
  location /health {
    access_log off;
    return 200 'ok';
    add_header Content-Type text/plain;
  }

  # Cache static assets
  location ~* \.(js|css|png|jpg|svg|ico|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
```

---

## Docker Compose

### `infrastructure/docker-compose.yml` (Development)

**Port conflict note:** Port 5432 commonly conflicts with existing PostgreSQL instances or other projects' containers. Before starting, check for conflicts with `ss -tlnp | grep 5432` or `docker ps --filter 'publish=5432'`. If port 5432 is taken, map to a different host port (e.g., `5433:5432`) and update `DATABASE_URL` in `.env` accordingly.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - '5432:5432'  # Change host port if 5432 is already in use
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build:
      context: ..
      dockerfile: infrastructure/docker/api.Dockerfile
    env_file: ../.env
    ports:
      - '3001:3001'
    depends_on:
      postgres:
        condition: service_healthy

  web:
    build:
      context: ..
      dockerfile: infrastructure/docker/web.Dockerfile
      args:
        VITE_API_URL: http://localhost:3001
    ports:
      - '5173:80'
    depends_on:
      - api

volumes:
  postgres_data:
```

### `infrastructure/docker-compose.prod.yml` (Self-Hosted Production)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U ${POSTGRES_USER}']
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    image: ${ECR_REGISTRY}/${ECR_REPO_API}:${IMAGE_TAG}
    restart: always
    env_file: .env.production
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'wget', '-qO-', 'http://localhost:3001/api/health']
      interval: 30s
      timeout: 5s
      retries: 3

  web:
    image: ${ECR_REGISTRY}/${ECR_REPO_WEB}:${IMAGE_TAG}
    restart: always
    ports:
      - '80:80'
      - '443:443'
    depends_on:
      - api
    volumes:
      - ./certs:/etc/nginx/certs:ro   # TLS certs (e.g. from Certbot)

volumes:
  postgres_data:
```

---

## GitHub Actions

### `ci.yml` (PR Checks)

Key practices:
- `pnpm/action-setup` with `run_install: false` — let `setup-node`'s `cache: 'pnpm'` handle the store cache
- `concurrency` — cancels in-progress runs for the same PR when a new commit is pushed
- Use `--affected` with Turborepo to skip unchanged packages
- Use `TURBO_TOKEN` + `TURBO_TEAM` for remote caching if available

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

# Cancel in-progress runs for the same branch/PR on new pushes
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: myapp_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # Required for Turborepo --affected to compare against base branch

      # Step 1: Set up pnpm (run_install: false — setup-node handles caching)
      - uses: pnpm/action-setup@v4
        with:
          version: 9
          run_install: false

      # Step 2: Set up Node with pnpm store cache
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Typecheck
        run: pnpm turbo run typecheck --affected

      - name: Lint
        run: pnpm lint

      - name: Generate Prisma client
        run: pnpm db:generate

      - name: Run migrations (test DB)
        run: pnpm --filter @myapp/database exec prisma migrate deploy
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/myapp_test

      - name: Unit + integration tests
        run: pnpm turbo run test --affected -- --coverage
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/myapp_test
          TEST_DATABASE_URL: postgresql://postgres:postgres@localhost:5432/myapp_test
          JWT_SECRET: test-secret-at-least-32-chars-long
          JWT_REFRESH_SECRET: test-refresh-secret-at-least-32-chars
          NODE_ENV: test
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
```

### `cd-staging.yml` (Deploy to Staging on `develop`)

```yaml
name: Deploy Staging

on:
  push:
    branches: [develop]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.ECR_REGISTRY }}/myapp
          tags: type=sha,prefix=staging-

      - name: Build and push API image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: infrastructure/docker/api.Dockerfile
          push: true
          tags: ${{ env.ECR_REGISTRY }}/myapp-api:${{ steps.meta.outputs.version }}

      - name: Build and push Web image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: infrastructure/docker/web.Dockerfile
          push: true
          tags: ${{ env.ECR_REGISTRY }}/myapp-web:${{ steps.meta.outputs.version }}
          build-args: VITE_API_URL=${{ secrets.STAGING_API_URL }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      # For ECS:
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster myapp-staging \
            --service myapp-api \
            --force-new-deployment
          aws ecs update-service \
            --cluster myapp-staging \
            --service myapp-web \
            --force-new-deployment

      # For EKS (alternative — uncomment if using Kubernetes):
      # - name: Deploy to EKS
      #   run: |
      #     aws eks update-kubeconfig --name myapp-staging --region ${{ env.AWS_REGION }}
      #     kubectl set image deployment/api api=${{ env.ECR_REGISTRY }}/myapp-api:${{ needs.build-and-push.outputs.image-tag }} -n myapp
      #     kubectl set image deployment/web web=${{ env.ECR_REGISTRY }}/myapp-web:${{ needs.build-and-push.outputs.image-tag }} -n myapp
```

### `cd-production.yml`

Same as `cd-staging.yml` with:
- Triggered on `push: branches: [main]`
- Clusters/namespaces pointing to production
- A manual approval gate (GitHub Environments with required reviewers)

---

## `.dockerignore`

Always include a `.dockerignore` at the repo root to prevent sensitive files and large directories from being sent to the build context:

```
node_modules
.git
**/.env
**/.env.*
**/dist
**/.turbo
**/coverage
*.md
.github
e2e
```

---

## Kubernetes: Kustomize vs Helm

**Use Kustomize for your own applications. Use Helm for third-party off-the-shelf software.**

| Scenario | Tool |
|----------|------|
| Deploying your own microservices (web, api) | **Kustomize** |
| Installing Prometheus, cert-manager, ingress-nginx | **Helm** |
| GitOps with Argo CD or Flux | **Kustomize** (native support) |
| Sharing infra config as a distributable package | **Helm** |

Kustomize is built into `kubectl` (`kubectl apply -k ./`) and uses pure YAML patching — no templating language, no `{{ .Values.something }}`. The overlay model maps naturally to dev/staging/production environment promotion.

## Kubernetes (Kustomize)

### `infrastructure/k8s/base/api-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: myapp-api:latest   # Kustomize overlay sets the actual tag
          ports:
            - containerPort: 3001
          envFrom:
            - secretRef:
                name: myapp-secrets
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3001
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3001
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

### `infrastructure/k8s/base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - api-deployment.yaml
  - web-deployment.yaml
  - services.yaml
  - ingress.yaml
```

### `infrastructure/k8s/overlays/production/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
namespace: myapp-production
images:
  - name: myapp-api
    newName: <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp-api
    newTag: "latest"   # CI overwrites this with the actual SHA tag
  - name: myapp-web
    newName: <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp-web
    newTag: "latest"
```

---

## Environment and Secrets

### Local Development

Copy `.env.example` to `.env` and fill in values. Never commit `.env`.

### GitHub Actions

Store secrets in GitHub repository secrets (`Settings → Secrets → Actions`):
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`
- `STAGING_API_URL`, `PRODUCTION_API_URL`
- `CODECOV_TOKEN`

### AWS (ECS/EKS)

Store application secrets in **AWS Secrets Manager**. The task definition or K8s secret references them — never bake secrets into images.

For EKS, create secrets with:
```bash
kubectl create secret generic myapp-secrets \
  --from-literal=DATABASE_URL="..." \
  --from-literal=JWT_SECRET="..." \
  -n myapp-production
```

### Environments

Three environments: `development` → `staging` → `production`

| Env | Branch | Database | Deploy trigger |
|-----|--------|----------|----------------|
| development | local | Docker Compose Postgres | manual `docker compose up` |
| staging | `develop` | RDS (staging) | auto on push to `develop` |
| production | `main` | RDS (production) | auto on push to `main` + manual approval |

Always run `prisma migrate deploy` as part of the deployment pipeline before the new containers start. Use an ECS task or K8s Job to run migrations before the rolling update.
