# GoormGB 비용 예측

## 프로젝트 기간

- **prod**: 3주
- **dev (미니PC)**: 2달 (Backend, Frontend, AI 모두)
- **총 프로젝트 기간**: 약 3개월

## Prod 환경 월간 비용

| 서비스 | 사양 | 월 비용 | 비고 |
|--------|------|---------|------|
| **EKS Control Plane** | 1 cluster | $73 | 고정 비용 |
| **EC2 (EKS 노드)** | 100% Spot, 5-8대 | ~$170 | m5.large 혼합 |
| **ECS Fargate (AI)** | Spot × 2, 1vCPU/2GB | ~$22 | AZ 분산 |
| **RDS PostgreSQL** | db.t4g.medium (Graviton) | ~$95 | Multi-AZ 활성화 |
| **ElastiCache Redis** | r6g.large × 3 shards (Graviton) | ~$325 | 대기열 처리 |
| **NAT Instance** | t3.micro × 2 (HA) | ~$16 | NAT Gateway 대비 ~$74 절감 |
| **S3** | 4 buckets (~100GB) | ~$5 | 수명주기 적용 |
| **CloudFront** | 5 distributions | ~$75 | 트래픽 의존 |
| **Route53** | 1 hosted zone | ~$1 | |
| **ALB** | 1 | ~$25 | |
| **Secrets Manager** | ~10 secrets | ~$5 | |
| **ECR** | 8 repositories | ~$3 | 이미지 저장 |
| **CloudWatch** | Logs, Metrics | ~$10 | 사용량 의존 |

### Prod 월간 총계: **~$825**

## Dev 환경 비용

### 미니PC (k3s) - Backend, Frontend, AI 모두

| 항목 | 구성 | 비용 |
|------|------|------|
| Backend (5개 MSA) | k3s Pods | $0 |
| Frontend | k3s Pod | $0 |
| **AI (2개 서비스)** | **k3s Pods** | **$0** |
| PostgreSQL | k3s Pod | $0 |
| Redis | k3s Pod | $0 |

> dev 환경은 미니PC k3s에서 모든 서비스를 실행합니다.
> AWS 비용이 발생하지 않습니다.

**Dev 2달 총계: $0**

## AI 데이터 비용 (MongoDB Atlas + S3)

### MongoDB Atlas

| 티어 | 저장 용량 | 월 비용 | 비고 |
|------|-----------|---------|------|
| **M0 Free** | 512MB | **$0** | TTL로 용량 관리 |
| Flex | 5GB | $8-30 | 상한 있음 (필요시) |

> TTL 설정으로 데이터 자동 삭제 → Free 티어로 충분

### S3 AI 버킷

| 버킷 | 용도 | 예상 용량 | 월 비용 |
|------|------|-----------|---------|
| ai-trajectory | 궤적 아카이브 | ~1GB/월 | ~$0.004 (Glacier IR) |
| ai-vqa-data | VQA 아카이브 | ~500MB/월 | ~$0.01 (Standard-IA) |
| ai-vqa-images | VQA 이미지 | ~2GB | ~$0.05 (Standard) |

### Lambda 백업

| 항목 | 월 비용 |
|------|---------|
| Lambda 실행 (30회/월) | ~$0.01 |
| CloudWatch Logs | ~$0.01 |

**AI 데이터 월간 총계: ~$0.08** (거의 무료)

## 비용 최적화 상세

### 1. NAT Instance vs NAT Gateway

| 항목 | NAT Gateway × 2 | NAT Instance × 2 |
|------|-----------------|------------------|
| 월 비용 | ~$90 | ~$16 |
| 데이터 처리 | $0.045/GB | 없음 |
| 가용성 | 관리형 HA | AZ별 1개 (HA) |
| 대역폭 | 45Gbps | 인스턴스 의존 |
| 관리 | AWS | 직접 관리 |

**선택: NAT Instance × 2** (고가용성 + 비용 절감)

### 2. 100% Spot vs On-Demand 혼합

| 구성 | 월 비용 | 비고 |
|------|---------|------|
| On-Demand 5대 | ~$340 | 안정적 |
| On-Demand 3대 + Spot 5대 | ~$270 | 혼합 |
| **100% Spot** | **~$150-180** | 비용 최적 |

**선택: 100% Spot** (Karpenter로 리스크 관리)

### 3. Fargate vs Fargate Spot

| 구성 | 월 비용 (2 tasks) |
|------|-------------------|
| 일반 Fargate | ~$70 |
| **Fargate Spot** | **~$22** |

**선택: Fargate Spot** (70% 절감)

### 4. Dev RDS: AWS vs Pod

| 구성 | 월 비용 | 비고 |
|------|---------|------|
| AWS RDS (db.t3.micro) | ~$15 | 관리형 |
| **k3s Pod (PostgreSQL)** | **$0** | 직접 관리 |

**선택: k3s Pod** (dev 환경은 비용 $0)

## 전체 프로젝트 비용 예측

### Prod (3주)

```
EKS + 노드 + RDS (Multi-AZ, Graviton) + Redis + 기타
= ~$825/월 × 0.75 (3주)
= ~$620
```

### Dev (2달)

```
미니PC (Backend, Frontend, AI, DB, Redis) = $0
```

### 총 비용

| 기간 | 환경 | 비용 |
|------|------|------|
| 3주 | prod | ~$620 |
| 2달 | dev (미니PC) | $0 |

**프로젝트 총 예상 비용: ~$620**

## 비용 모니터링

### AWS Cost Explorer 설정

```hcl
# 태그 기반 비용 추적
tags = {
  Project     = "goormgb"
  Environment = "prod"  # 또는 "dev"
  Service     = "eks"   # 서비스별 구분
  ManagedBy   = "terraform"
}
```

### 예산 알림 설정

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "goormgb-monthly-budget"
  budget_type  = "COST"
  limit_amount = "1000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["212clab@gmail.com"]
  }
}
```

## 비용 절감 체크리스트

- [x] NAT Gateway → NAT Instance × 2
- [x] EKS 100% Spot
- [x] ECS Fargate Spot
- [x] S3 수명주기 정책
- [x] ECR 이미지 수명주기
- [x] Reserved Instance 미사용 (단기 프로젝트)
- [x] dev 환경 미니PC 활용 (Backend, Frontend, AI 모두)
- [x] dev RDS/Redis → k3s Pod
- [x] **MongoDB Atlas Free** (TTL로 용량 관리)
- [x] **S3 Glacier IR** (AI 아카이브 저렴하게 보관)
- [x] **Lambda 백업** (자동화로 수동 작업 제거)
- [x] **RDS Graviton (db.t4g)** (ARM 기반 비용 효율)
- [x] **ElastiCache Graviton (r6g)** (ARM 기반 비용 효율)
- [ ] CloudFront 캐싱 최적화 (운영 중 조정)
- [ ] Spot 인스턴스 타입 다양화

## 비용 비교 (최적화 전 vs 후)

| 항목 | 최적화 전 | 최적화 후 | 절감액 |
|------|-----------|-----------|--------|
| NAT | $90 (Gateway×2) | $16 (Instance×2) | $74 |
| EKS 노드 | $340 | $170 (Spot) | $170 |
| ECS Fargate | $70 | $22 (Spot) | $48 |
| RDS | $120 (t3 Multi-AZ) | $95 (t4g Multi-AZ) | $25 |
| ElastiCache | $400 (r5) | $325 (r6g Graviton) | $75 |
| Dev RDS/Redis | $75 | $0 (Pod) | $75 |
| AI DB (MongoDB) | $57 (DocumentDB) | $0 (Atlas Free) | $57 |
| AI 아카이브 | $23 (Standard) | $0.08 (Glacier) | $23 |
| **월 총계** | **~$1,350** | **~$825** | **~$525 (39%)** |

### 3주 기준 실제 비용: **~$620**
