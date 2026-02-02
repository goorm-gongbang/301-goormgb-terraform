# GoormGB Terraform Infrastructure

티켓팅 플랫폼 GoormGB의 AWS 인프라를 관리하는 Terraform 프로젝트입니다.

## 프로젝트 개요

| 항목      | 내용                             |
| --------- | -------------------------------- |
| 도메인    | goormgb.space                    |
| Prod 환경 | AWS (EKS, ECS, RDS, ElastiCache) |
| Dev 환경  | 미니PC (k3s)                     |
| 예상 비용 | ~$620 (Prod 3주)                 |

## 아키텍처

```
[Dev - 미니PC k3s]                    [Prod - AWS]
┌─────────────────┐                  ┌─────────────────────────────┐
│ Frontend        │                  │ Route53 → CloudFront → S3  │
│ Backend (5 MSA) │                  │           ↓                │
│ AI (2 서비스)   │                  │ ALB → EKS (Backend)        │
│ PostgreSQL      │                  │     → ECS (AI)             │
│ Redis           │                  │           ↓                │
│                 │                  │ RDS + ElastiCache          │
│ 비용: $0        │                  │ 비용: ~$825/월             │
└─────────────────┘                  └─────────────────────────────┘
        │                                       │
        └───────────── MongoDB Atlas ───────────┘
                      (Free, 공유)
```

## 프로젝트 구조

```
301-goormgb-terraform/
├── modules/                    # Terraform 모듈
│   ├── vpc/                    # VPC, Subnet, NAT Instance
│   ├── eks/                    # EKS Cluster, Karpenter
│   ├── ecs/                    # ECS Fargate (AI)
│   ├── rds/                    # RDS PostgreSQL
│   ├── elasticache/            # ElastiCache Redis
│   ├── s3/                     # S3 Buckets (7개)
│   ├── cloudfront/             # CloudFront Distributions
│   ├── route53/                # DNS
│   ├── acm/                    # SSL 인증서
│   ├── ecr/                    # Container Registry
│   ├── iam/                    # IAM Roles & Policies
│   ├── secrets/                # Secrets Manager
│   └── lambda-mongodb-backup/  # MongoDB 백업 Lambda
│
├── environments/               # 환경별 설정
│   ├── shared/                 # 공유 리소스 (ECR, Route53, IAM)
│   ├── dev/                    # Dev 환경
│   ├── prod/                   # Prod 환경
│   └── ai/                     # AI 환경 (Prod ECS)
│
├── .github/workflows/          # CI/CD
│   └── terraform.yml           # PR → plan, merge → apply
│
├── scripts/                    # 운영 스크립트
│   ├── mongodb-backup/         # MongoDB → S3 백업
│   ├── s3-restore/             # S3 → MongoDB 복원
│   ├── sql/                    # SQL 스키마
│   ├── migrate-policies.sh     # Dev → Prod 마이그레이션
│   └── README.md
│
└── docs/                       # 문서
    ├── ARCHITECTURE.md         # 아키텍처 상세
    ├── COST.md                 # 비용 분석
    ├── RUNBOOK.md              # 운영 가이드
    ├── IAM.md                  # IAM 사용자/그룹/Role 관리
    ├── HELM_GUIDE.md           # Helm 차트 가이드
    ├── MONGODB_ATLAS.md        # MongoDB 설정
    ├── LAMBDA_BACKUP.md        # Lambda 백업 가이드
    ├── S3_DATA_REUSE.md        # S3 AI 데이터 재사용
    ├── S3_LOGS.md              # S3 로그 버킷 및 배치 업로드
    └── DATA_MIGRATION.md       # 데이터 마이그레이션
```

## 빠른 시작

### 1. 사전 요구사항

```bash
# Terraform 설치
brew install terraform

# AWS CLI 설정
aws configure
```

### 2. 공유 리소스 배포 (최초 1회)

```bash
cd environments/shared
terraform init
terraform apply
```

### 3. Prod 환경 배포

```bash
cd environments/prod
terraform init
terraform apply
```

## 주요 기능

### 비용 최적화 (39% 절감)

| 최적화                     | 절감액  |
| -------------------------- | ------- |
| NAT Gateway → NAT Instance | $74/월  |
| EKS 100% Spot              | $170/월 |
| ECS Fargate Spot           | $48/월  |
| Dev 미니PC 활용            | $75/월  |
| MongoDB Atlas Free         | $57/월  |

### AI 데이터 파이프라인

```
[사용자 궤적/VQA] → [MongoDB Atlas] → [Lambda 백업] → [S3 Glacier]
                         │                              │
                         └─── TTL 7일 ────→ 자동 삭제 ──┘
                                            (백업 후)
```

### 스케일링 전략

- **EKS**: Karpenter + 100% Spot (티켓 오픈 시 자동 확장)
- **ECS**: Fargate Spot × 2 (AZ 분산)
- **Redis**: 3 Shards (티켓 대기열 처리)

## 문서

| 문서                                        | 설명                             |
| ------------------------------------------- | -------------------------------- |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md)     | 전체 아키텍처                    |
| [COST.md](docs/COST.md)                     | 비용 분석 및 최적화              |
| [RUNBOOK.md](docs/RUNBOOK.md)               | 운영 가이드                      |
| [IAM.md](docs/IAM.md)                       | IAM 사용자/그룹/Role 관리        |
| [HELM_GUIDE.md](docs/HELM_GUIDE.md)         | Helm 차트 가이드                 |
| [MONGODB_ATLAS.md](docs/MONGODB_ATLAS.md)   | MongoDB 설정                     |
| [S3_DATA_REUSE.md](docs/S3_DATA_REUSE.md)   | S3 데이터 재사용                 |
| [S3_LOGS.md](docs/S3_LOGS.md)               | S3 로그 버킷 구조 및 배치 업로드 |
| [DATA_MIGRATION.md](docs/DATA_MIGRATION.md) | 데이터 마이그레이션              |

## CI/CD

PR 생성 시 자동으로 `terraform plan`이 실행되고, main 머지 시 `terraform apply`가 실행됩니다.

```
PR 생성/업데이트 → terraform plan (결과 PR 코멘트)
        ↓
    리뷰 & 승인
        ↓
  main 머지 → terraform apply (shared → dev → prod → ai)
```

## 환경별 비용

| 환경              | 기간  | 월 비용 | 총 비용   |
| ----------------- | ----- | ------- | --------- |
| **Prod**          | 3주   | ~$825   | ~$620     |
| **Dev (미니PC)**  | 2달   | $0      | $0        |
| **MongoDB Atlas** | 3개월 | $0      | $0        |
| **총계**          |       |         | **~$620** |

> RDS: Graviton (db.t4g.medium) + Multi-AZ / ElastiCache: Graviton (r6g)

## 관련 링크

- MongoDB Atlas: https://cloud.mongodb.com
- AWS Console: https://console.aws.amazon.com
- Terraform Registry: https://registry.terraform.io
