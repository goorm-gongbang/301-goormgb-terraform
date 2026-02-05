# Lambda MongoDB Backup 가이드

## 개요

MongoDB Atlas의 데이터를 TTL 만료 전에 S3로 자동 백업하는 Lambda 함수입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    백업 프로세스 흐름                            │
│                                                                 │
│  EventBridge                                                    │
│  (매일 03:00 KST)                                               │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Lambda Function                       │   │
│  │                                                         │   │
│  │  1. Secrets Manager에서 MongoDB URI 조회               │   │
│  │  2. MongoDB Atlas 연결                                  │   │
│  │  3. TTL 만료 예정 데이터 조회                           │   │
│  │  4. JSON 직렬화 + GZIP 압축                            │   │
│  │  5. S3 업로드                                          │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      S3 Buckets                          │   │
│  │                                                         │   │
│  │  goormgb-ai-trajectory-prod/                           │   │
│  │    └── user_trajectories/2024/01/15/030000.json.gz     │   │
│  │                                                         │   │
│  │  goormgb-ai-vqa-data-prod/                             │   │
│  │    ├── vqa_quizzes/2024/01/15/030000.json.gz          │   │
│  │    └── vqa_results/2024/01/15/daily.json.gz           │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  CloudWatch Alarm                                               │
│  (백업 실패 시 SNS 알림)                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 백업 스케줄

| 컬렉션            | TTL  | 백업 시점        | S3 버킷       |
| ----------------- | ---- | ---------------- | ------------- |
| user_trajectories | 7일  | 6-7일차 데이터   | ai-trajectory |
| vqa_quizzes       | 30일 | 29-30일차 데이터 | ai-vqa-data   |
| vqa_results       | 없음 | 전날 데이터      | ai-vqa-data   |

## 배포 방법

### 1. Lambda 패키지 빌드

```bash
cd scripts/mongodb-backup
chmod +x build.sh
./build.sh
```

### 2. Secrets Manager 설정

```bash
# MongoDB URI를 Secrets Manager에 저장
aws secretsmanager create-secret \
  --name goormgb/ai/mongodb \
  --secret-string '{
    "uri": "mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/?retryWrites=true&w=majority"
  }'

# Secret ARN 확인 (Terraform 변수로 사용)
aws secretsmanager describe-secret \
  --secret-id goormgb/ai/mongodb \
  --query 'ARN' --output text
```

### 3. Terraform 적용

```hcl
# environments/prod/main.tf

module "mongodb_backup" {
  source = "../../modules/lambda-mongodb-backup"

  name        = "goormgb"
  environment = "prod"

  lambda_zip_path       = "../../scripts/mongodb-backup/mongodb-backup.zip"
  mongodb_secret_arn    = "arn:aws:secretsmanager:ap-northeast-2:123456789:secret:goormgb/ai/mongodb-xxxxx"
  trajectory_bucket_id  = module.s3.ai_trajectory_bucket_id
  trajectory_bucket_arn = module.s3.ai_trajectory_bucket_arn
  vqa_data_bucket_id    = module.s3.ai_vqa_data_bucket_id
  vqa_data_bucket_arn   = module.s3.ai_vqa_data_bucket_arn

  trajectory_ttl_days = 7
  vqa_ttl_days        = 30

  # 선택: 알림 설정
  alarm_sns_topic_arn = aws_sns_topic.alerts.arn

  tags = local.tags
}
```

```bash
cd environments/prod
terraform init
terraform apply
```

### 4. 수동 테스트

```bash
# Lambda 수동 실행
aws lambda invoke \
  --function-name goormgb-mongodb-backup-prod \
  --payload '{}' \
  response.json

# 결과 확인
cat response.json
```

## S3 저장 구조

```
goormgb-ai-trajectory-prod/
└── user_trajectories/
    └── 2024/
        └── 01/
            ├── 15/
            │   └── 030000.json.gz
            ├── 16/
            │   └── 030000.json.gz
            └── 17/
                └── 030000.json.gz

goormgb-ai-vqa-data-prod/
├── vqa_quizzes/
│   └── 2024/01/15/030000.json.gz
└── vqa_results/
    └── 2024/01/15/daily.json.gz
```

## 백업 데이터 복원

### S3에서 데이터 다운로드

```bash
# 특정 날짜 백업 다운로드
aws s3 cp \
  s3://goormgb-ai-trajectory-prod/user_trajectories/2024/01/15/030000.json.gz \
  ./backup.json.gz

# 압축 해제
gunzip backup.json.gz

# 내용 확인
cat backup.json | jq '.[0]'
```

### MongoDB에 복원

```javascript
// mongosh
use goormgb

// JSON 파일 로드 (로컬에서)
const data = JSON.parse(cat("backup.json"))

// 컬렉션에 삽입
db.user_trajectories_restored.insertMany(data)
```

### Python으로 복원

```python
import json
import gzip
import boto3
from pymongo import MongoClient

# S3에서 다운로드
s3 = boto3.client('s3')
response = s3.get_object(
    Bucket='goormgb-ai-trajectory-prod',
    Key='user_trajectories/2024/01/15/030000.json.gz'
)

# 압축 해제 및 파싱
data = json.loads(gzip.decompress(response['Body'].read()))

# MongoDB에 복원
client = MongoClient("mongodb+srv://...")
db = client.goormgb
db.user_trajectories_restored.insert_many(data)
```

## 모니터링

### CloudWatch Logs

```bash
# 로그 그룹
/aws/lambda/goormgb-mongodb-backup-prod

# 최근 로그 확인
aws logs tail /aws/lambda/goormgb-mongodb-backup-prod --follow
```

### CloudWatch Metrics

| 메트릭               | 설명         |
| -------------------- | ------------ |
| Invocations          | 실행 횟수    |
| Errors               | 에러 횟수    |
| Duration             | 실행 시간    |
| ConcurrentExecutions | 동시 실행 수 |

### 알림 설정

```hcl
# SNS 토픽 생성
resource "aws_sns_topic" "alerts" {
  name = "goormgb-alerts"
}

# 이메일 구독
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "team@example.com"
}
```

## 비용

| 항목                       | 예상 비용  |
| -------------------------- | ---------- |
| Lambda 실행 (30회/월)      | ~$0.01     |
| S3 저장 (Glacier IR, 10GB) | ~$0.04     |
| CloudWatch Logs            | ~$0.01     |
| **월 총계**                | **~$0.06** |

## 트러블슈팅

### Lambda 타임아웃

```
Task timed out after 300.00 seconds
```

**해결**:

- Lambda timeout 증가 (최대 15분)
- 데이터 범위 축소 (TTL 기간 조정)

### MongoDB 연결 실패

```
ServerSelectionTimeoutError: connection closed
```

**해결**:

- MongoDB Atlas IP Whitelist 확인
- Lambda VPC 설정 확인 (NAT Gateway 필요)

### S3 권한 오류

```
AccessDenied: Access Denied
```

**해결**:

- Lambda IAM Role에 S3 권한 확인
- 버킷 정책 확인

## 관련 문서

- [MongoDB Atlas 설정](./MONGODB_ATLAS.md)
- [S3 아키텍처](./ARCHITECTURE.md)
