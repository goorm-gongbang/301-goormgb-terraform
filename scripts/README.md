# Scripts

AI 데이터 관련 스크립트 모음입니다.

## 폴더 구조

```
scripts/
├── mongodb-backup/          # MongoDB → S3 백업 (Lambda)
│   ├── handler.py           # Lambda 핸들러
│   ├── build.sh             # 배포 패키지 빌드
│   └── requirements.txt
│
├── s3-restore/              # S3 → MongoDB 복원
│   ├── restore.py           # MongoDB 복원 스크립트
│   ├── restore.sh           # Bash 래퍼
│   ├── download.py          # 로컬 다운로드
│   └── requirements.txt
│
├── sql/                     # SQL 스키마
│   └── ai_policies_schema.sql
│
└── migrate-policies.sh      # PostgreSQL 마이그레이션
```

## 사용법

### MongoDB 백업 (Lambda)

```bash
# 패키지 빌드
cd scripts/mongodb-backup
./build.sh

# AWS Lambda에 배포
aws lambda update-function-code \
  --function-name goormgb-mongodb-backup-prod \
  --zip-file fileb://mongodb-backup.zip
```

### S3 → MongoDB 복원

```bash
export MONGODB_URI="mongodb+srv://..."

# 특정 날짜 복원
./scripts/s3-restore/restore.sh \
  --date 2024-01-15 \
  --collection user_trajectories

# 로컬 다운로드
./scripts/s3-restore/download.py \
  --date 2024-01-15 \
  --collection user_trajectories \
  --output ./data/
```

### PostgreSQL 마이그레이션 (Dev → Prod)

```bash
export RDS_HOST="goormgb-prod.xxxxx.rds.amazonaws.com"
export RDS_PASSWORD="your_password"

./scripts/migrate-policies.sh
```

### SQL 스키마 적용

```bash
# Dev (미니PC k3s)
kubectl exec -n db postgres-0 -- \
  psql -U goormgb -d goormgb_ai \
  -f /path/to/ai_policies_schema.sql

# Prod (RDS)
PGPASSWORD=$RDS_PASSWORD psql \
  -h $RDS_HOST -U goormgb -d goormgb_ai \
  -f scripts/sql/ai_policies_schema.sql
```

## 관련 문서

- [MongoDB Atlas 설정](../docs/MONGODB_ATLAS.md)
- [Lambda 백업 가이드](../docs/LAMBDA_BACKUP.md)
- [S3 데이터 재사용](../docs/S3_DATA_REUSE.md)
- [데이터 마이그레이션](../docs/DATA_MIGRATION.md)
