# S3 아카이브 데이터 재사용 가이드

## 개요

MongoDB Atlas에서 TTL로 삭제되기 전에 S3에 백업된 데이터를 재사용하는 방법입니다.

## 아카이브 구조

```
goormgb-ai-trajectory-prod/
└── user_trajectories/
    └── 2024/
        └── 01/
            ├── 15/030000.json.gz  (1월 15일 백업)
            ├── 16/030000.json.gz  (1월 16일 백업)
            └── 17/030000.json.gz  (1월 17일 백업)

goormgb-ai-vqa-data-prod/
├── vqa_quizzes/
│   └── 2024/01/15/030000.json.gz
└── vqa_results/
    └── 2024/01/15/daily.json.gz
```

---

## 워크플로우 1: 일상적인 분석 (Athena SQL)

S3 데이터를 **직접 SQL로 조회**하는 가장 간편한 방법입니다.

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    Athena 분석 워크플로우                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [S3 Archive]                                                   │
│  ai-trajectory/                                                 │
│  ai-vqa-data/                                                   │
│       │                                                         │
│       │ (직접 스캔)                                             │
│       ▼                                                         │
│  ┌─────────────────┐                                           │
│  │  AWS Athena     │                                           │
│  │                 │                                           │
│  │  SELECT *       │                                           │
│  │  FROM archive   │                                           │
│  │  WHERE ...      │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                           │
│  │  분석 결과       │  → 대시보드, 리포트                       │
│  └─────────────────┘                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1단계: Athena 테이블 생성 (최초 1회)

```sql
-- Athena에서 실행

-- 궤적 데이터 테이블
CREATE EXTERNAL TABLE IF NOT EXISTS trajectory_archive (
    _id STRUCT<`$oid`: STRING>,
    userId STRING,
    sessionId STRING,
    trajectory STRUCT<
        events: ARRAY<STRUCT<
            type: STRING,
            target: STRING,
            timestamp: BIGINT,
            position: INT
        >>,
        metadata: STRUCT<
            browser: STRING,
            device: STRING,
            screenSize: STRING
        >
    >,
    createdAt STRUCT<`$date`: STRING>
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
    'ignore.malformed.json' = 'true'
)
LOCATION 's3://goormgb-ai-trajectory-prod/user_trajectories/'
TBLPROPERTIES ('has_encrypted_data'='false');

-- VQA 퀴즈 테이블
CREATE EXTERNAL TABLE IF NOT EXISTS vqa_quizzes_archive (
    _id STRUCT<`$oid`: STRING>,
    quizId STRING,
    userId STRING,
    imageUrl STRING,
    question STRING,
    options ARRAY<STRING>,
    correctAnswer STRING,
    createdAt STRUCT<`$date`: STRING>
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://goormgb-ai-vqa-data-prod/vqa_quizzes/'
TBLPROPERTIES ('has_encrypted_data'='false');

-- VQA 결과 테이블
CREATE EXTERNAL TABLE IF NOT EXISTS vqa_results_archive (
    _id STRUCT<`$oid`: STRING>,
    resultId STRING,
    userId STRING,
    quizId STRING,
    userAnswer STRING,
    isCorrect BOOLEAN,
    responseTimeMs INT,
    createdAt STRUCT<`$date`: STRING>
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://goormgb-ai-vqa-data-prod/vqa_results/'
TBLPROPERTIES ('has_encrypted_data'='false');
```

### 2단계: 분석 쿼리 예시

```sql
-- 1. 특정 사용자의 모든 궤적 조회
SELECT
    userId,
    sessionId,
    trajectory.events,
    createdAt
FROM trajectory_archive
WHERE userId = 'user_123'
ORDER BY createdAt.`$date` DESC
LIMIT 100;

-- 2. 일별 활성 사용자 수
SELECT
    SUBSTR(createdAt.`$date`, 1, 10) as date,
    COUNT(DISTINCT userId) as unique_users,
    COUNT(*) as total_sessions
FROM trajectory_archive
GROUP BY SUBSTR(createdAt.`$date`, 1, 10)
ORDER BY date DESC;

-- 3. 매크로 의심 패턴 분석 (빠른 클릭)
SELECT
    userId,
    COUNT(*) as session_count,
    AVG(CARDINALITY(trajectory.events)) as avg_events_per_session
FROM trajectory_archive
GROUP BY userId
HAVING AVG(CARDINALITY(trajectory.events)) > 100
ORDER BY avg_events_per_session DESC
LIMIT 50;

-- 4. VQA 정답률 분석
SELECT
    userId,
    COUNT(*) as total_attempts,
    SUM(CASE WHEN isCorrect THEN 1 ELSE 0 END) as correct_count,
    ROUND(AVG(CASE WHEN isCorrect THEN 1.0 ELSE 0.0 END) * 100, 2) as accuracy_pct,
    AVG(responseTimeMs) as avg_response_time
FROM vqa_results_archive
GROUP BY userId
ORDER BY total_attempts DESC
LIMIT 100;

-- 5. 특정 기간 데이터 조회
SELECT *
FROM trajectory_archive
WHERE createdAt.`$date` >= '2024-01-01T00:00:00Z'
  AND createdAt.`$date` < '2024-02-01T00:00:00Z';
```

### 비용

| 항목 | 비용 |
|------|------|
| 스캔 데이터 | $5 / TB |
| 1GB 스캔 | ~$0.005 |

> 💡 파티션을 활용하면 스캔 비용을 줄일 수 있습니다.

---

## 워크플로우 2: ML 학습 (Google Colab)

S3 데이터를 다운로드하여 **머신러닝 모델 학습**에 활용합니다.

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    ML 학습 워크플로우                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [S3 Archive]                                                   │
│       │                                                         │
│       │ 다운로드 (boto3)                                        │
│       ▼                                                         │
│  ┌─────────────────┐                                           │
│  │  Google Colab   │                                           │
│  │  / Jupyter      │                                           │
│  │                 │                                           │
│  │  1. 데이터 로드 │                                           │
│  │  2. 전처리      │                                           │
│  │  3. 학습        │                                           │
│  │  4. 평가        │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    학습 결과 활용                         │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │   │
│  │  │ 매크로 탐지 │  │ 위험도 점수 │  │ 정책 업데이트│      │   │
│  │  │ 모델        │  │ 모델        │  │             │      │   │
│  │  └─────────────┘  └─────────────┘  └──────┬──────┘      │   │
│  │                                           │              │   │
│  └───────────────────────────────────────────│──────────────┘   │
│                                              ▼                   │
│                                    ┌─────────────────┐          │
│                                    │  PostgreSQL     │          │
│                                    │  policies 테이블│          │
│                                    └─────────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Google Colab 노트북 예시

```python
# =============================================================================
# 1. 환경 설정
# =============================================================================
!pip install boto3 pymongo pandas scikit-learn

import boto3
import gzip
import json
import pandas as pd
from datetime import datetime, timedelta
from google.colab import userdata

# AWS 자격 증명 (Colab Secrets 사용)
AWS_ACCESS_KEY = userdata.get('AWS_ACCESS_KEY')
AWS_SECRET_KEY = userdata.get('AWS_SECRET_KEY')

s3 = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name='ap-northeast-2'
)

# =============================================================================
# 2. S3에서 데이터 로드
# =============================================================================
def load_s3_archive(bucket: str, prefix: str, start_date: datetime, end_date: datetime):
    """날짜 범위의 아카이브 데이터 로드"""
    all_data = []
    current = start_date

    while current <= end_date:
        date_prefix = f"{prefix}/{current.strftime('%Y/%m/%d')}/"

        try:
            response = s3.list_objects_v2(Bucket=bucket, Prefix=date_prefix)

            for obj in response.get('Contents', []):
                print(f"Loading: {obj['Key']}")
                data = s3.get_object(Bucket=bucket, Key=obj['Key'])
                content = gzip.decompress(data['Body'].read())
                records = json.loads(content)
                all_data.extend(records)

        except Exception as e:
            print(f"Skip {date_prefix}: {e}")

        current += timedelta(days=1)

    print(f"Total records loaded: {len(all_data)}")
    return all_data

# 최근 30일 궤적 데이터 로드
end_date = datetime.now()
start_date = end_date - timedelta(days=30)

trajectories = load_s3_archive(
    bucket='goormgb-ai-trajectory-prod',
    prefix='user_trajectories',
    start_date=start_date,
    end_date=end_date
)

# =============================================================================
# 3. 데이터 전처리
# =============================================================================
def extract_features(trajectory):
    """궤적에서 특성 추출"""
    events = trajectory.get('trajectory', {}).get('events', [])

    if len(events) < 2:
        return None

    # 클릭 간격 계산
    timestamps = [e['timestamp'] for e in events if 'timestamp' in e]
    intervals = [timestamps[i+1] - timestamps[i] for i in range(len(timestamps)-1)]

    return {
        'userId': trajectory.get('userId'),
        'sessionId': trajectory.get('sessionId'),
        'event_count': len(events),
        'duration_ms': max(timestamps) - min(timestamps) if timestamps else 0,
        'avg_interval_ms': sum(intervals) / len(intervals) if intervals else 0,
        'std_interval_ms': pd.Series(intervals).std() if len(intervals) > 1 else 0,
        'min_interval_ms': min(intervals) if intervals else 0,
        'click_count': sum(1 for e in events if e.get('type') == 'click'),
    }

# 특성 추출
features = [extract_features(t) for t in trajectories]
features = [f for f in features if f is not None]

df = pd.DataFrame(features)
print(df.describe())

# =============================================================================
# 4. 매크로 탐지 모델 학습
# =============================================================================
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

# 특성 선택
X = df[['event_count', 'avg_interval_ms', 'std_interval_ms', 'min_interval_ms', 'click_count']]

# 스케일링
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Isolation Forest (이상 탐지)
model = IsolationForest(contamination=0.1, random_state=42)
df['is_anomaly'] = model.fit_predict(X_scaled)
df['anomaly_score'] = model.decision_function(X_scaled)

# 이상 패턴 확인
anomalies = df[df['is_anomaly'] == -1]
print(f"탐지된 이상 세션: {len(anomalies)}개")
print(anomalies.head(10))

# =============================================================================
# 5. 정책 업데이트 (PostgreSQL)
# =============================================================================
# 탐지된 패턴을 기반으로 위험도 규칙 생성
new_rules = {
    'fast_click_threshold': float(anomalies['min_interval_ms'].quantile(0.9)),
    'low_std_threshold': float(anomalies['std_interval_ms'].quantile(0.1)),
    'high_event_threshold': int(anomalies['event_count'].quantile(0.9)),
}

print("새로운 위험도 규칙:")
print(json.dumps(new_rules, indent=2))

# PostgreSQL에 저장 (선택)
# import psycopg2
# conn = psycopg2.connect(...)
# cur.execute("UPDATE risk_rules SET conditions = %s WHERE name = 'learned_pattern'",
#             [json.dumps(new_rules)])
```

### 비용

| 항목 | 비용 |
|------|------|
| S3 데이터 전송 (다운로드) | $0.09 / GB |
| Google Colab | 무료 (GPU 제한적) |
| Colab Pro | $10 / 월 |

---

## 워크플로우 3: 데이터 복원 (MongoDB)

S3 아카이브 데이터를 **MongoDB에 복원**하여 재분석합니다.

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    데이터 복원 워크플로우                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [S3 Archive]                                                   │
│  ai-trajectory/                                                 │
│  ai-vqa-data/                                                   │
│       │                                                         │
│       │ restore-from-s3.py                                      │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    MongoDB Atlas                          │   │
│  │                                                          │   │
│  │  [기존 컬렉션]            [복원 컬렉션]                   │   │
│  │  user_trajectories        user_trajectories_restored     │   │
│  │  vqa_quizzes              vqa_quizzes_restored           │   │
│  │  vqa_results              vqa_results_restored           │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│       │                                                         │
│       │ 재분석                                                  │
│       ▼                                                         │
│  ┌─────────────────┐                                           │
│  │  AI 서비스       │                                           │
│  │  재분석/검증     │                                           │
│  └─────────────────┘                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 복원 스크립트 사용법

```bash
# 환경변수 설정
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export MONGODB_URI="mongodb+srv://user:pass@cluster.mongodb.net"

# 특정 날짜의 궤적 데이터 복원
./scripts/restore-from-s3.py \
    --bucket goormgb-ai-trajectory-prod \
    --collection user_trajectories \
    --date 2024-01-15

# 날짜 범위로 복원
./scripts/restore-from-s3.py \
    --bucket goormgb-ai-trajectory-prod \
    --collection user_trajectories \
    --start-date 2024-01-01 \
    --end-date 2024-01-31

# VQA 데이터 복원
./scripts/restore-from-s3.py \
    --bucket goormgb-ai-vqa-data-prod \
    --collection vqa_quizzes \
    --date 2024-01-15

# 복원 후 컬렉션 이름 지정
./scripts/restore-from-s3.py \
    --bucket goormgb-ai-trajectory-prod \
    --collection user_trajectories \
    --date 2024-01-15 \
    --target-collection user_trajectories_jan15
```

### 복원 후 활용

```javascript
// MongoDB Shell에서 복원된 데이터 분석

// 복원된 데이터 확인
db.user_trajectories_restored.countDocuments()

// 특정 사용자 궤적 조회
db.user_trajectories_restored.find({ userId: "user_123" })

// 집계 분석
db.user_trajectories_restored.aggregate([
    {
        $group: {
            _id: "$userId",
            sessionCount: { $sum: 1 },
            avgEvents: { $avg: { $size: "$trajectory.events" } }
        }
    },
    { $sort: { sessionCount: -1 } },
    { $limit: 10 }
])

// 분석 완료 후 정리
db.user_trajectories_restored.drop()
```

### 비용

| 항목 | 비용 |
|------|------|
| S3 데이터 전송 | $0.09 / GB |
| MongoDB Atlas | $0 (Free 티어 내) |

---

## 비교 요약

| 워크플로우 | 용도 | 난이도 | 비용 |
|------------|------|--------|------|
| **Athena SQL** | 일상 분석, 대시보드 | 쉬움 | $5/TB |
| **Colab ML** | 모델 학습, 패턴 탐지 | 중간 | 거의 무료 |
| **MongoDB 복원** | 상세 분석, 디버깅 | 쉬움 | 거의 무료 |

## 추천 시나리오

| 상황 | 추천 워크플로우 |
|------|-----------------|
| "이번 달 매크로 의심 사용자 목록 뽑아줘" | Athena SQL |
| "새로운 매크로 패턴 학습시켜줘" | Colab ML |
| "1월 15일 특정 사용자 궤적 다시 분석해줘" | MongoDB 복원 |
| "전체 데이터로 리포트 만들어줘" | Athena SQL |
| "정책 효과 검증해줘" | Colab ML + Athena |
