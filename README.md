
# GoormGB Terraform Infrastructure

GoormGB의 티켓팅 플랫폼 AWS 인프라를 관리하는 Terraform 프로젝트입니다.

## 프로젝트 개요

| 항목 | 내용 |
| --- | --- |
| **도메인** | `goormgb.space` |
| **Prod 환경** | **AWS Full Managed** (EKS, ECS, RDS, ElastiCache) |
| **Dev 환경** | **Hybrid** (AWS CloudFront/S3 + On-Premise MiniPC) |
| **예상 비용** | ~$620 (Prod 3주) |

## 아키텍처

### Production (AWS)

전형적인 AWS Cloud Native 아키텍처로, EKS(백엔드)와 ECS(AI)를 사용하며 모든 데이터베이스는 AWS 관리형 서비스를 사용합니다.

```mermaid
graph LR
    User((User)) --> R53[Route53]
    R53 --> CF[CloudFront]
    CF --> S3[S3 Bucket<br/>(Frontend)]
    CF --> ALB[ALB]
    ALB --> EKS[EKS Cluster<br/>(Backend)]
    ALB --> ECS[ECS Fargate<br/>(AI Service)]
    EKS --> RDS[(RDS PostgreSQL)]
    EKS --> EC[(ElastiCache Redis)]

```

### Development (Hybrid)

비용 절감을 위해 컴퓨팅은 온프레미(MiniPC)를 사용하되, **배포 환경(CDN, SSL, 정적 호스팅)은 Prod와 동일하게 AWS를 사용**하여 실제 운영 환경과의 격차를 줄였습니다.

```mermaid
graph TD
    User((User)) -->|dev.goormgb.space| R53[Route53]
    R53 --> CF[CloudFront]
    
    subgraph AWS Cloud
        CF -->|Static Content| S3[S3 Bucket<br/>(Frontend)]
    end
    
    subgraph On-Premise
        CF -->|API Request<br/>(HTTPS)| MiniPC[MiniPC k3s<br/>(origin-dev)]
        MiniPC --> DB[(PostgreSQL)]
        MiniPC --> Redis[(Redis)]
    end

```

## 프로젝트 구조

루트 디렉토리의 공통 리소스가 `environments/shared`로 통합되어 구조가 명확해졌습니다.

```
301-goormgb-terraform/
├── modules/                    # Terraform 모듈
│   ├── vpc/                    # VPC, Subnet, NAT Instance
│   ├── eks/                    # EKS Cluster, Karpenter
│   ├── ecs/                    # ECS Fargate (AI)
│   ├── rds/                    # RDS PostgreSQL
│   ├── elasticache/            # ElastiCache Redis
│   ├── s3/                     # S3 Buckets (Frontend/Logs)
│   ├── cloudfront/             # CloudFront (CDN)
│   ├── route53/                # DNS Records
│   ├── acm/                    # SSL 인증서
│   ├── ecr/                    # Container Registry
│   ├── iam/                    # IAM Roles & Users
│   ├── secrets/                # Secrets Manager
│   └── lambda-mongodb-backup/  # MongoDB 백업 Lambda
│
├── environments/               # 환경별 격리된 설정
│   ├── shared/                 # 공통 리소스 (ECR, IAM, Route53 Zone, OIDC)
│   ├── dev/                    # Dev 환경 (S3, CloudFront, Route53 -> MiniPC)
│   ├── prod/                   # Prod 환경 (Full AWS Infra)
│   └── ai/                     # AI 환경 (Prod ECS 분리)
│
├── .github/workflows/          # CI/CD
│   └── terraform.yml           # PR → plan, merge → apply
│
└── docs/                       # 상세 문서
    ├── ARCHITECTURE.md         # 아키텍처 상세
    ├── COST.md                 # 비용 분석
    └── ...

```

## 빠른 시작

### 1. 사전 요구사항

```bash
# Terraform 설치
brew install terraform

# AWS CLI 설정
aws configure

```

### 2. 공유 리소스 배포 (필수, 최초 1회)

IAM, ECR, OIDC 등 모든 환경에서 공유하는 리소스를 먼저 생성합니다.

```bash
cd environments/shared
terraform init
terraform apply

```

### 3. Dev 환경 배포 (Hybrid)

CloudFront, S3, Route53 등 Dev 환경의 AWS 리소스를 배포합니다.

```bash
cd environments/dev
terraform init
terraform apply

```

### 4. Prod 환경 배포

실제 운영을 위한 전체 AWS 인프라를 배포합니다.

```bash
cd environments/prod
terraform init
terraform apply

```

## 주요 기능 및 최적화 전략

### 1. 비용 최적화 (Total ~$620)

| 전략 | 내용 | 절감 효과 |
| --- | --- | --- |
| **Hybrid Dev** | 개발 서버는 미니PC 활용, CDN/DNS만 AWS 사용 | 컴퓨팅 비용 $0 |
| **Spot Instance** | EKS/ECS 100% Spot 인스턴스 활용 | 온디맨드 대비 ~70% 절감 |
| **NAT Instance** | NAT Gateway 대신 EC2 t4g.nano 사용 | 월 $74 절약 |

### 2. Dev 환경의 고도화

단순 로컬 서버가 아닌, **CloudFront + S3** 구조를 도입하여 다음과 같은 이점을 얻었습니다.

* **Prod 환경 일치**: CDN 캐싱 정책과 SSL 설정을 미리 검증 가능
* **보안 강화**: MiniPC의 실제 IP(`origin-dev`)를 숨기고 CloudFront(`dev`)를 통해서만 접근 허용
* **HTTPS 적용**: ACM 인증서를 통해 개발 환경에서도 보안 연결 지원

### 3. AI 데이터 파이프라인

```
[사용자 궤적/VQA] → [MongoDB Atlas] → [Lambda 백업] → [S3 Glacier]
                         │                              │
                         └─── TTL 7일 ────→ 자동 삭제 ──┘

```

## CI/CD 파이프라인

Github Actions를 통해 환경별로 자동 배포됩니다.

1. **PR 생성/수정**: `terraform plan` 실행 (결과를 PR 코멘트로 작성)
2. **Main Merge**: `terraform apply` 실행
* 순서: `shared` → `dev` → `prod` → `ai`



## 환경별 비용 상세

| 환경 | 기간 | 주요 리소스 | 예상 비용 |
| --- | --- | --- | --- |
| **Prod** | 3주 | EKS, RDS, ALB, NAT | ~$620 |
| **Dev** | 2달 | CloudFront, S3, Route53 | ~$5 (미만) |
| **Shared** | 상시 | ECR, Route53 Zone | ~$1 |
| **총계** |  |  | **~$626** |

> **Note**: Dev 환경의 컴퓨팅 비용은 미니PC 사용으로 $0입니다. AWS 비용은 트래픽 및 도메인 비용만 발생합니다.

## 관련 링크

* **MongoDB Atlas**: [https://cloud.mongodb.com](https://cloud.mongodb.com)
* **AWS Console**: [https://console.aws.amazon.com](https://console.aws.amazon.com)
* **Terraform Registry**: [https://registry.terraform.io](https://registry.terraform.io)