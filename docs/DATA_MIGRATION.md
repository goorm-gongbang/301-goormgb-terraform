# 데이터 마이그레이션 가이드

## 개요

Dev 환경(미니PC)에서 Prod 환경(AWS)으로 데이터를 마이그레이션하는 방법을 설명합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      데이터 마이그레이션 흐름                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [Dev - 미니PC k3s]                    [Prod - AWS]                         │
│                                                                              │
│  ┌─────────────────┐                  ┌─────────────────┐                   │
│  │ PostgreSQL Pod  │                  │ RDS PostgreSQL  │                   │
│  │                 │                  │                 │                   │
│  │ ├─ policies     │  ─── pg_dump ──→ │ ├─ policies     │                   │
│  │ ├─ risk_rules   │                  │ ├─ risk_rules   │                   │
│  │ └─ macro_patterns│                 │ └─ macro_patterns│                  │
│  └─────────────────┘                  └─────────────────┘                   │
│                                                                              │
│  ┌─────────────────┐                  ┌─────────────────┐                   │
│  │ MongoDB Atlas   │                  │ MongoDB Atlas   │                   │
│  │ (dev 계정)      │   ← 별도 관리 →  │ (prod 계정)     │                   │
│  │                 │                  │                 │                   │
│  │ 궤적/VQA 수집   │                  │ 궤적/VQA 수집   │                   │
│  └─────────────────┘                  └─────────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## PostgreSQL 정책 마이그레이션

### 마이그레이션 대상 테이블

| 테이블 | 설명 | 마이그레이션 |
|--------|------|--------------|
| `policies` | 매크로 탐지 정책 | ✅ 필수 |
| `policy_versions` | 정책 버전 히스토리 | ✅ 필수 |
| `risk_rules` | 위험도 판별 규칙 | ✅ 필수 |
| `macro_patterns` | 알려진 매크로 패턴 | ✅ 필수 |
| `detection_results` | 탐지 결과 로그 | ❌ 환경별 분리 |
| `vqa_verification_results` | VQA 검증 결과 | ❌ 환경별 분리 |

### 사전 준비

#### 1. Dev 환경 (미니PC)

```bash
# k3s 클러스터 접근 확인
kubectl get pods -n db

# PostgreSQL Pod 확인
kubectl exec -n db postgres-0 -- psql -U goormgb -d goormgb_ai -c "SELECT version()"
```

#### 2. Prod 환경 (AWS RDS)

```bash
# RDS 엔드포인트 확인
aws rds describe-db-instances \
  --query 'DBInstances[?DBInstanceIdentifier==`goormgb-prod`].Endpoint.Address' \
  --output text

# RDS 연결 테스트
PGPASSWORD=$RDS_PASSWORD psql \
  -h goormgb-prod.xxxxx.ap-northeast-2.rds.amazonaws.com \
  -U goormgb -d goormgb_ai -c "SELECT 1"
```

### 스키마 초기화 (최초 1회)

```bash
# Prod RDS에 스키마 생성
PGPASSWORD=$RDS_PASSWORD psql \
  -h $RDS_HOST -U goormgb -d goormgb_ai \
  -f scripts/sql/ai_policies_schema.sql
```

### 마이그레이션 실행

```bash
# 환경변수 설정
export RDS_HOST="goormgb-prod.xxxxx.ap-northeast-2.rds.amazonaws.com"
export RDS_PASSWORD="your_secure_password"

# 마이그레이션 실행
./scripts/migrate-policies.sh
```

### 출력 예시

```
[2024-01-15 10:30:00] ==========================================
[2024-01-15 10:30:00] PostgreSQL 정책 마이그레이션 시작
[2024-01-15 10:30:00] ==========================================
[2024-01-15 10:30:00] 요구사항 확인 중...
[2024-01-15 10:30:00] 요구사항 확인 완료
[2024-01-15 10:30:01] === Dev PostgreSQL에서 데이터 내보내기 ===
[2024-01-15 10:30:01] 내보내는 테이블: policies policy_versions risk_rules macro_patterns
[2024-01-15 10:30:02] 덤프 완료: data/migrations/policies_20240115_103000.sql (24K)
[2024-01-15 10:30:02] === Prod RDS에 데이터 가져오기 ===
[2024-01-15 10:30:02] RDS 연결 테스트 중...
[2024-01-15 10:30:03] RDS 연결 성공
[2024-01-15 10:30:03] 데이터 가져오기 중...
[2024-01-15 10:30:05] 데이터 가져오기 완료
[2024-01-15 10:30:05] === 마이그레이션 검증 ===
[2024-01-15 10:30:05] ✅ policies: 5 rows (일치)
[2024-01-15 10:30:05] ✅ policy_versions: 12 rows (일치)
[2024-01-15 10:30:06] ✅ risk_rules: 8 rows (일치)
[2024-01-15 10:30:06] ✅ macro_patterns: 15 rows (일치)
[2024-01-15 10:30:06] ==========================================
[2024-01-15 10:30:06] 마이그레이션 완료!
[2024-01-15 10:30:06] ==========================================
```

## MongoDB Atlas 데이터

### Dev/Prod 분리 전략

MongoDB Atlas는 Dev와 Prod를 **완전히 분리**합니다.

| 환경 | MongoDB Atlas | 용도 |
|------|---------------|------|
| Dev | `goormgb-dev.xxxxx.mongodb.net` | 개발/테스트 데이터 수집 |
| Prod | `goormgb-prod.xxxxx.mongodb.net` | 실제 운영 데이터 수집 |

### 데이터 마이그레이션이 필요한 경우

일반적으로 MongoDB 데이터는 마이그레이션하지 않습니다 (환경별 독립 수집).

하지만 필요한 경우:

```bash
# Dev에서 내보내기
mongodump \
  --uri="mongodb+srv://goormgb_ai:xxx@goormgb-dev.xxxxx.mongodb.net/goormgb" \
  --collection=vqa_quizzes \
  --out=./mongo_dump

# Prod에 가져오기
mongorestore \
  --uri="mongodb+srv://goormgb_ai:xxx@goormgb-prod.xxxxx.mongodb.net/goormgb" \
  --collection=vqa_quizzes \
  ./mongo_dump/goormgb/vqa_quizzes.bson
```

## 배포 체크리스트

### Prod 배포 전

- [ ] Dev에서 정책 데이터 테스트 완료
- [ ] 마이그레이션 스크립트 테스트
- [ ] RDS 스키마 초기화 완료
- [ ] RDS 연결 정보 확인

### 마이그레이션 실행

- [ ] `migrate-policies.sh` 실행
- [ ] 마이그레이션 검증 (row count 확인)
- [ ] Prod AI 서비스에서 정책 로드 테스트

### 마이그레이션 후

- [ ] Prod AI 서비스 배포
- [ ] 정책 적용 확인
- [ ] 모니터링 대시보드 확인

## 롤백

### PostgreSQL 롤백

```bash
# 덤프 파일로 복원
PGPASSWORD=$RDS_PASSWORD psql \
  -h $RDS_HOST -U goormgb -d goormgb_ai \
  -f data/migrations/policies_YYYYMMDD_HHMMSS.sql
```

### 이전 버전으로 롤백

```sql
-- 특정 정책을 이전 버전으로 롤백
UPDATE policies p
SET rules = pv.rules,
    updated_at = NOW()
FROM policy_versions pv
WHERE p.id = pv.policy_id
  AND pv.version = (
    SELECT MAX(version) - 1
    FROM policy_versions
    WHERE policy_id = p.id
  )
  AND p.name = 'default_macro_detection';
```

## 자동화 (CI/CD)

### GitHub Actions 예시

```yaml
# .github/workflows/migrate-policies.yml
name: Migrate Policies to Prod

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "MIGRATE" to confirm'
        required: true

jobs:
  migrate:
    if: github.event.inputs.confirm == 'MIGRATE'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Configure k3s kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.K3S_KUBECONFIG }}" > ~/.kube/config

      - name: Run migration
        env:
          RDS_HOST: ${{ secrets.RDS_HOST }}
          RDS_PASSWORD: ${{ secrets.RDS_PASSWORD }}
        run: |
          chmod +x scripts/migrate-policies.sh
          ./scripts/migrate-policies.sh

      - name: Upload dump artifact
        uses: actions/upload-artifact@v3
        with:
          name: migration-dump
          path: data/migrations/*.sql
```

## 트러블슈팅

### kubectl 연결 실패

```bash
# k3s 컨텍스트 확인
kubectl config current-context

# Pod 상태 확인
kubectl get pods -n db -o wide
```

### RDS 연결 실패

```bash
# Security Group 확인
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[].IpPermissions'

# 로컬 IP가 허용되어 있는지 확인
curl ifconfig.me
```

### 데이터 불일치

```sql
-- Dev와 Prod의 차이 확인
-- Dev에서 실행
SELECT name, updated_at FROM policies ORDER BY name;

-- Prod에서 동일하게 실행하여 비교
```
