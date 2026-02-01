# Helm Chart 구성 가이드

이 문서는 GoormGB 인프라의 Helm Chart 구성을 위한 가이드입니다.
Helm Chart를 만들 때 참고하세요.

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 프로젝트명 | GoormGB (티켓팅 플랫폼) |
| 도메인 | goormgb.space |
| Dev 환경 | 미니PC k3s |
| Prod 환경 | AWS EKS |

## 환경 구성

### Dev 환경 (미니PC k3s)

| 구성요소 | 배포 방식 | 비고 |
|----------|-----------|------|
| Frontend | Helm | Next.js |
| Backend (5개) | Helm | Spring Boot MSA |
| AI (2개) | Helm | FastAPI |
| PostgreSQL | Helm (Bitnami) | pgvector 필요 |
| Redis | Helm (Bitnami) | Standalone |

### Prod 환경 (AWS EKS)

| 구성요소 | 배포 방식 | 비고 |
|----------|-----------|------|
| Frontend | Helm | Next.js SSR |
| Backend (5개) | Helm | Spring Boot MSA |
| AI (2개) | **ECS Fargate** | Helm 아님 (Terraform) |
| PostgreSQL | **AWS RDS** | Helm 아님 |
| Redis | **AWS ElastiCache** | Helm 아님 |
| Observability | Helm | Prometheus, Grafana, Loki |

## 서비스 목록

### Frontend

```yaml
# goormgb-frontend
name: goormgb-frontend
type: Next.js (SSR + Static)
port: 3000

resources:
  dev:
    replicas: 1
    cpu: 500m
    memory: 512Mi
  prod:
    replicas: 2
    cpu: 1000m
    memory: 1Gi

env:
  - NEXT_PUBLIC_API_URL
  - NEXT_PUBLIC_WS_URL
```

### Backend MSA (5개)

```yaml
# 공통 설정
framework: Spring Boot
port: 8080
healthCheck: /actuator/health

services:
  - name: goormgb-backend-auth
    description: 인증/인가 서비스
    dependencies: [PostgreSQL, Redis]

  - name: goormgb-backend-queue
    description: 티켓 대기열 서비스
    dependencies: [Redis]
    critical: true  # 티켓 오픈 시 핵심

  - name: goormgb-backend-seat
    description: 좌석 관리 서비스
    dependencies: [PostgreSQL, Redis]

  - name: goormgb-backend-order
    description: 주문/결제 서비스
    dependencies: [PostgreSQL]

  - name: goormgb-backend-admin
    description: 관리자 서비스
    dependencies: [PostgreSQL]

resources:
  dev:
    replicas: 1
    cpu: 500m
    memory: 512Mi
  prod:
    replicas: 2-5  # HPA
    cpu: 1000m
    memory: 1Gi
```

### AI 서비스 (2개)

```yaml
# Dev에서만 Helm 배포 (Prod는 ECS)
framework: FastAPI
port: 8000
healthCheck: /health

services:
  - name: goormgb-ai-control
    description: AI Control Plane (상시 실행)
    dependencies: [PostgreSQL, Redis, MongoDB]

  - name: goormgb-ai-test
    description: Test Automation (필요 시 실행)
    dependencies: [MongoDB]
    replicas: 0  # 기본 0, 필요 시 scale up

resources:
  dev:
    replicas: 1
    cpu: 500m
    memory: 1Gi
```

## 환경 변수

### 공통

```yaml
# Dev
DATABASE_URL: postgresql://goormgb:password@postgres:5432/goormgb
REDIS_URL: redis://redis:6379
MONGODB_URI: mongodb+srv://...@goormgb-dev.mongodb.net

# Prod
DATABASE_URL: postgresql://goormgb:${RDS_PASSWORD}@${RDS_HOST}:5432/goormgb
REDIS_URL: redis://${ELASTICACHE_HOST}:6379
MONGODB_URI: mongodb+srv://...@goormgb-prod.mongodb.net
```

### 서비스별

```yaml
# Frontend
NEXT_PUBLIC_API_URL: https://api.goormgb.space  # Prod
NEXT_PUBLIC_API_URL: http://backend-gateway:8080  # Dev

# Backend (공통)
SPRING_PROFILES_ACTIVE: dev | prod
JWT_SECRET: ${JWT_SECRET}
CORS_ALLOWED_ORIGINS: https://goormgb.space

# AI
OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
LLM_MODEL: gpt-4-turbo
```

## Helm 폴더 구조 (권장)

```
helm/
├── charts/
│   ├── goormgb-frontend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── hpa.yaml
│   │       └── configmap.yaml
│   │
│   ├── goormgb-backend/          # 공통 차트 (5개 서비스용)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-auth.yaml
│   │   ├── values-queue.yaml
│   │   ├── values-seat.yaml
│   │   ├── values-order.yaml
│   │   └── values-admin.yaml
│   │
│   ├── goormgb-ai/               # AI 서비스 (Dev Only)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │
│   └── goormgb-infra/            # 인프라 (Dev Only)
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── postgres.yaml     # Bitnami subchart
│           └── redis.yaml        # Bitnami subchart
│
├── environments/
│   ├── dev/
│   │   ├── values.yaml           # 환경 공통
│   │   └── secrets.yaml          # 시크릿 (gitignore)
│   └── prod/
│       ├── values.yaml
│       └── secrets.yaml
│
└── helmfile.yaml                 # 전체 배포 관리
```

## values.yaml 예시

### goormgb-backend/values.yaml (공통)

```yaml
# 기본값
replicaCount: 1

image:
  repository: 123456789.dkr.ecr.ap-northeast-2.amazonaws.com/goormgb-backend
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

env:
  SPRING_PROFILES_ACTIVE: dev

# 서비스별 오버라이드용
serviceName: ""
servicePort: 8080
```

### values-queue.yaml (대기열 서비스 전용)

```yaml
serviceName: goormgb-backend-queue

replicaCount: 2

image:
  tag: queue-latest

env:
  SPRING_PROFILES_ACTIVE: prod
  REDIS_CLUSTER_ENABLED: "true"

resources:
  limits:
    cpu: 2000m
    memory: 2Gi

# HPA (티켓 오픈 시 중요)
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### environments/dev/values.yaml

```yaml
global:
  environment: dev
  domain: dev.goormgb.space

  image:
    registry: 123456789.dkr.ecr.ap-northeast-2.amazonaws.com
    pullPolicy: Always
    tag: dev

  database:
    host: postgres
    port: 5432
    name: goormgb

  redis:
    host: redis
    port: 6379

  mongodb:
    uri: mongodb+srv://goormgb_ai:xxx@goormgb-dev.mongodb.net

# 인프라 (Dev만)
infrastructure:
  postgres:
    enabled: true
    auth:
      postgresPassword: devpassword
      database: goormgb
    primary:
      persistence:
        size: 10Gi
    # pgvector 활성화
    image:
      repository: pgvector/pgvector
      tag: pg16

  redis:
    enabled: true
    architecture: standalone
    auth:
      enabled: false
```

### environments/prod/values.yaml

```yaml
global:
  environment: prod
  domain: goormgb.space

  image:
    registry: 123456789.dkr.ecr.ap-northeast-2.amazonaws.com
    pullPolicy: Always
    tag: prod

  database:
    host: goormgb-prod.xxxxx.ap-northeast-2.rds.amazonaws.com
    port: 5432
    name: goormgb

  redis:
    host: goormgb-prod.xxxxx.cache.amazonaws.com
    port: 6379

  mongodb:
    uri: mongodb+srv://goormgb_ai:xxx@goormgb-prod.mongodb.net

# 인프라 (Prod는 AWS 사용)
infrastructure:
  postgres:
    enabled: false  # AWS RDS 사용
  redis:
    enabled: false  # AWS ElastiCache 사용
```

## Ingress 설정

### Dev (미니PC)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: goormgb-ingress
  annotations:
    kubernetes.io/ingress.class: traefik  # k3s 기본
spec:
  rules:
    - host: dev.goormgb.space
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: goormgb-frontend
                port:
                  number: 3000
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: goormgb-backend-gateway
                port:
                  number: 8080
```

### Prod (AWS ALB)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: goormgb-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  rules:
    - host: goormgb.space
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: goormgb-frontend
                port:
                  number: 3000
```

## CI/CD 연동

### TeamCity (Backend/Frontend)

```
[TeamCity - GCP]
     │
     ├─→ Build (gradle/npm)
     ├─→ Test
     ├─→ Docker build
     ├─→ Push to ECR
     │         │
     │         ▼
     │   [AWS ECR]
     │         │
     └─→ Update GitOps repo (values.yaml의 image.tag)
               │
               ▼
         [ArgoCD - EKS]
               │
               └─→ Helm upgrade (자동 sync)
```

### GitHub Actions (AI)

```yaml
# .github/workflows/deploy-ai.yml
name: Deploy AI

on:
  push:
    branches: [main]
    paths: ['ai/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build and push to ECR
        run: |
          docker build -t goormgb-ai-control ./ai
          docker push $ECR_REGISTRY/goormgb-ai-control:$GITHUB_SHA

      # Dev: Helm 배포
      - name: Deploy to Dev (Helm)
        if: github.ref == 'refs/heads/develop'
        run: |
          helm upgrade goormgb-ai ./helm/charts/goormgb-ai \
            -f ./helm/environments/dev/values.yaml \
            --set image.tag=$GITHUB_SHA

      # Prod: ECS 배포
      - name: Deploy to Prod (ECS)
        if: github.ref == 'refs/heads/main'
        run: |
          aws ecs update-service \
            --cluster goormgb-prod \
            --service goormgb-ai-control \
            --force-new-deployment
```

## Helmfile (전체 배포)

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

environments:
  dev:
    values:
      - environments/dev/values.yaml
  prod:
    values:
      - environments/prod/values.yaml

releases:
  # 인프라 (Dev만)
  - name: goormgb-infra
    chart: ./charts/goormgb-infra
    condition: infrastructure.enabled

  # Frontend
  - name: goormgb-frontend
    chart: ./charts/goormgb-frontend
    values:
      - ./charts/goormgb-frontend/values-{{ .Environment.Name }}.yaml

  # Backend (5개)
  - name: goormgb-backend-auth
    chart: ./charts/goormgb-backend
    values:
      - ./charts/goormgb-backend/values-auth.yaml

  - name: goormgb-backend-queue
    chart: ./charts/goormgb-backend
    values:
      - ./charts/goormgb-backend/values-queue.yaml

  - name: goormgb-backend-seat
    chart: ./charts/goormgb-backend
    values:
      - ./charts/goormgb-backend/values-seat.yaml

  - name: goormgb-backend-order
    chart: ./charts/goormgb-backend
    values:
      - ./charts/goormgb-backend/values-order.yaml

  - name: goormgb-backend-admin
    chart: ./charts/goormgb-backend
    values:
      - ./charts/goormgb-backend/values-admin.yaml

  # AI (Dev만)
  - name: goormgb-ai
    chart: ./charts/goormgb-ai
    condition: ai.enabled  # Prod에서는 ECS 사용
```

## 배포 명령어

```bash
# Dev 전체 배포
helmfile -e dev apply

# Prod 배포 (인프라 제외)
helmfile -e prod apply

# 특정 서비스만 배포
helmfile -e dev -l name=goormgb-backend-queue apply

# Dry-run
helmfile -e prod diff
```

## 주의사항

1. **Prod AI는 ECS**: Prod에서 AI 서비스는 Helm이 아니라 AWS ECS Fargate로 배포
2. **Prod DB는 AWS**: RDS, ElastiCache 사용 (Helm 인프라 차트 비활성화)
3. **ECR 이미지 풀**: ServiceAccount에 ECR 접근 권한 필요
4. **Secrets**: 민감 정보는 Kubernetes Secrets 또는 AWS Secrets Manager 사용

## 관련 문서

- [ARCHITECTURE.md](./ARCHITECTURE.md) - 전체 아키텍처
- [COST.md](./COST.md) - 비용 분석
- [DATA_MIGRATION.md](./DATA_MIGRATION.md) - Dev → Prod 마이그레이션
