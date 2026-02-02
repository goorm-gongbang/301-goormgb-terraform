# GoormGB Terraform Infrastructure

GoormGB 티켓팅 플랫폼을 위한 AWS 인프라 코드입니다.

## 프로젝트 개요

- **서비스**: 티켓팅 플랫폼 (추천시스템 + AI 봇 방어)
- **도메인**: goormgb.space
- **클라우드**: AWS (ap-northeast-2)
- **예상 동시접속**: 100만 (티켓 오픈 시)

## 디렉토리 구조

```
301-goormgb-terraform/
├── docs/                        # 문서
│   ├── README.md                # 이 파일
│   ├── ARCHITECTURE.md          # 아키텍처 다이어그램
│   ├── COST.md                  # 비용 예측
│   ├── RUNBOOK.md               # 운영 가이드
│   └── decisions/               # ADR (Architecture Decision Records)
│
├── environments/                # 환경별 설정
│   ├── shared/                  # 공통 리소스 (ECR, IAM)
│   ├── dev/                     # dev 환경 (Route53만)
│   ├── prod/                    # prod 환경 (전체 인프라)
│   └── ai/                      # AI 전용 (dev/prod 선택)
│
└── modules/                     # 재사용 가능한 모듈
    ├── vpc/                     # VPC, Subnets, NAT Instance
    ├── ecr/                     # Container Registry
    ├── eks/                     # EKS Cluster (100% Spot)
    ├── ecs/                     # ECS Fargate (AI 서비스)
    ├── rds/                     # PostgreSQL + pgvector
    ├── elasticache/             # Redis Cluster
    ├── s3/                      # S3 Buckets
    ├── cloudfront/              # CDN Distributions
    ├── route53/                 # DNS
    ├── acm/                     # SSL 인증서
    ├── secrets/                 # Secrets Manager
    └── iam/                     # IAM Groups, Users
```

## 환경 구성

| 환경       | 설명        | 인프라                               |
| ---------- | ----------- | ------------------------------------ |
| **shared** | 공통 리소스 | ECR (8개), IAM                       |
| **dev**    | 개발 환경   | Route53 레코드 (미니PC k3s)          |
| **prod**   | 운영 환경   | VPC, EKS, RDS, Redis, S3, CloudFront |
| **ai**     | AI 서비스   | ECS Fargate Spot (dev/prod 선택)     |

## 적용 순서

```bash
# 1. 공통 리소스 (최초 1회)
cd environments/shared
terraform init
terraform apply

# 2. dev 환경
cd environments/dev
terraform init
terraform apply

# 3. prod 환경
cd environments/prod
terraform init
terraform apply

# 4. AI 환경 (dev)
cd environments/ai
terraform init
terraform apply -var="environment=dev"

# 5. AI 환경 (prod)
terraform apply -var="environment=prod"
```

## 기술 스택

### Backend

- Java 21, Spring Boot 4.0.2
- PostgreSQL (RDS), Redis (ElastiCache)

### Frontend

- TypeScript, Next.js 16
- Tailwind CSS, Shadcn UI

### AI

- Python 3.12, FastAPI, LangGraph
- 외부 LLM API (OpenRouter/OpenAI)

### Infrastructure

- EKS (100% Spot + Karpenter)
- ECS Fargate Spot (AI)
- Istio Service Mesh
- OTel + Prometheus + Loki + Grafana

## 비용 최적화

- **100% Spot Instance**: EKS 노드, ECS Fargate
- **NAT Instance**: NAT Gateway 대비 ~$74/월 절감
- **RDS Graviton (db.t4g.medium)**: ARM 기반 + Multi-AZ
- **ElastiCache Graviton (r6g.large)**: ARM 기반 Redis
- **S3 수명주기**: prefix별 차등 삭제 (AI 30일, 인프라 3일, 웹 14일)
- **ECR 수명주기**: 오래된 이미지 자동 삭제

**예상 비용**: ~$620 (Prod 3주)

## 관련 문서

| 문서                                 | 설명                             |
| ------------------------------------ | -------------------------------- |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 상세 아키텍처                    |
| [COST.md](./COST.md)                 | 비용 예측                        |
| [RUNBOOK.md](./RUNBOOK.md)           | 운영 가이드                      |
| [IAM.md](./IAM.md)                   | IAM 사용자/그룹/Role 관리        |
| [S3_LOGS.md](./S3_LOGS.md)           | S3 로그 버킷 구조 및 배치 업로드 |
| [HELM_GUIDE.md](./HELM_GUIDE.md)     | Helm 차트 가이드                 |
