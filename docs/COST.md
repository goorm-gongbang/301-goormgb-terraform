# GoormGB 비용 예측

## 프로젝트 기간

- **prod**: 3-4주 (약 1달)
- **dev (AI AWS)**: 2.5달
- **총 프로젝트 기간**: 4개월

## Prod 환경 월간 비용

| 서비스 | 사양 | 월 비용 | 비고 |
|--------|------|---------|------|
| **EKS Control Plane** | 1 cluster | $73 | 고정 비용 |
| **EC2 (EKS 노드)** | 100% Spot, 5-8대 | ~$150-180 | m5.large 혼합 |
| **ECS Fargate (AI)** | Spot × 2, 1vCPU/2GB | ~$22 | AZ 분산 |
| **RDS PostgreSQL** | db.t3.medium | ~$60 | Multi-AZ 미사용 |
| **ElastiCache Redis** | r6g.large × 3 shards | ~$300-350 | 대기열 처리 |
| **NAT Instance** | t3.micro | ~$8 | NAT Gateway 대비 $32 절감 |
| **S3** | 4 buckets (~100GB) | ~$5 | 수명주기 적용 |
| **CloudFront** | 5 distributions | ~$50-100 | 트래픽 의존 |
| **Route53** | 1 hosted zone | ~$1 | |
| **ALB** | 1 | ~$25 | |
| **Secrets Manager** | ~10 secrets | ~$5 | |
| **ECR** | 8 repositories | ~$3 | 이미지 저장 |
| **CloudWatch** | Logs, Metrics | ~$10-20 | 사용량 의존 |

### Prod 월간 총계: **~$710-850**

## Dev 환경 비용

### 미니PC (k3s) - 추천

| 항목 | 비용 |
|------|------|
| AWS 비용 | **$0** |
| 전기세 | 미니PC 자체 비용 |

### AI Dev (AWS Fargate Spot)

| 서비스 | 사양 | 월 비용 |
|--------|------|---------|
| ECS Fargate Spot | 1vCPU/2GB × 1 | ~$11 |

**AI dev 2.5달 총계: ~$28**

## 비용 최적화 상세

### 1. NAT Instance vs NAT Gateway

| 항목 | NAT Gateway | NAT Instance |
|------|-------------|--------------|
| 월 비용 | ~$45 | ~$8-10 |
| 데이터 처리 | $0.045/GB | 없음 |
| 가용성 | 관리형 HA | 단일 인스턴스 |
| 대역폭 | 45Gbps | 인스턴스 의존 |

**선택: NAT Instance** (4개월 프로젝트, 비용 우선)

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

### 4. RDS Reserved vs On-Demand

| 구성 | 월 비용 | 비고 |
|------|---------|------|
| On-Demand | ~$60 | 유연함 |
| Reserved 1년 | ~$36 | 40% 절감 |

**선택: On-Demand** (4개월 프로젝트)

## 전체 프로젝트 비용 예측

### Prod (3-4주 = 1달)

```
EKS + 노드 + 기타 서비스
= ~$710-850
```

### Dev (2.5달)

```
AI Fargate Spot = ~$11/월 × 2.5달 = ~$28
미니PC 기타 서비스 = $0
```

### 총 비용

| 기간 | 환경 | 비용 |
|------|------|------|
| 1달 | prod | ~$750 |
| 2.5달 | AI dev (AWS) | ~$28 |
| 2.5달 | dev (미니PC) | $0 |

**4개월 총 예상 비용: ~$780**

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

- [x] NAT Gateway → NAT Instance
- [x] EKS 100% Spot
- [x] ECS Fargate Spot
- [x] S3 수명주기 정책
- [x] ECR 이미지 수명주기
- [x] Reserved Instance 미사용 (4개월)
- [x] dev 환경 미니PC 활용
- [ ] CloudFront 캐싱 최적화 (운영 중 조정)
- [ ] Spot 인스턴스 타입 다양화

## 비용 비교 (최적화 전 vs 후)

| 항목 | 최적화 전 | 최적화 후 | 절감액 |
|------|-----------|-----------|--------|
| NAT | $45 | $8 | $37 |
| EKS 노드 | $340 | $170 | $170 |
| ECS Fargate | $70 | $22 | $48 |
| **월 총계** | **~$1,100** | **~$750** | **~$350 (32%)** |
