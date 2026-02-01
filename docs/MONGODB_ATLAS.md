# MongoDB Atlas 설정 가이드

## 개요

GoormGB AI 서비스는 MongoDB Atlas를 사용하여 다음 데이터를 저장합니다:

| 컬렉션 | 용도 | TTL |
|--------|------|-----|
| `user_trajectories` | 사용자 궤적 데이터 | 7일 |
| `vqa_quizzes` | VQA 퀴즈 데이터 | 30일 |
| `vqa_results` | VQA 결과 | 없음 (아카이브) |

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    데이터 흐름                               │
│                                                             │
│  [AI Service]                                               │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────┐    TTL 만료 전    ┌─────────────────────┐  │
│  │  MongoDB    │ ───────────────→  │  Lambda (매일)      │  │
│  │  Atlas Free │                   │  - mongodump        │  │
│  │             │                   │  - S3 업로드        │  │
│  │  - 궤적     │                   └──────────┬──────────┘  │
│  │  - VQA      │                              │             │
│  └─────────────┘                              ▼             │
│                                    ┌─────────────────────┐  │
│                                    │  S3 Buckets         │  │
│                                    │  - ai-trajectory    │  │
│                                    │  - ai-vqa-data      │  │
│                                    │  - ai-vqa-images    │  │
│                                    └─────────────────────┘  │
│                                                             │
│  [분석 결과]                                                │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────┐                                           │
│  │ PostgreSQL  │  ← 분석 결과만 영구 저장                   │
│  │ (RDS 공유)  │                                           │
│  └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

## MongoDB Atlas 설정

### 1. 계정 생성 및 클러스터 생성

1. [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) 접속
2. 회원가입 또는 로그인
3. "Create a New Cluster" 클릭
4. **M0 Sandbox (Free)** 선택
5. Cloud Provider: **AWS**
6. Region: **ap-northeast-2 (Seoul)** 선택
7. Cluster Name: `goormgb-ai`

### 2. 네트워크 설정

```bash
# Network Access → Add IP Address
# 개발 중에는 0.0.0.0/0 허용 (임시)
# 프로덕션에서는 AWS NAT Instance IP만 허용
```

### 3. 데이터베이스 사용자 생성

```bash
# Database Access → Add New Database User
Username: goormgb_ai
Password: <강력한 비밀번호>
Role: readWriteAnyDatabase
```

### 4. 연결 문자열 획득

```bash
# Clusters → Connect → Connect your application
# Driver: Python 3.12 or later

mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/?retryWrites=true&w=majority
```

## 컬렉션 및 인덱스 설정

### MongoDB Shell 접속

```bash
mongosh "mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/goormgb"
```

### 컬렉션 생성 및 TTL 인덱스

```javascript
// 데이터베이스 선택
use goormgb

// 1. 사용자 궤적 컬렉션 (7일 TTL)
db.createCollection("user_trajectories")
db.user_trajectories.createIndex(
  { "createdAt": 1 },
  { expireAfterSeconds: 604800 }  // 7일
)
db.user_trajectories.createIndex({ "userId": 1 })
db.user_trajectories.createIndex({ "sessionId": 1 })

// 2. VQA 퀴즈 컬렉션 (30일 TTL)
db.createCollection("vqa_quizzes")
db.vqa_quizzes.createIndex(
  { "createdAt": 1 },
  { expireAfterSeconds: 2592000 }  // 30일
)
db.vqa_quizzes.createIndex({ "quizId": 1 })
db.vqa_quizzes.createIndex({ "userId": 1 })

// 3. VQA 결과 컬렉션 (TTL 없음 - 아카이브 대상)
db.createCollection("vqa_results")
db.vqa_results.createIndex({ "resultId": 1 })
db.vqa_results.createIndex({ "userId": 1 })
db.vqa_results.createIndex({ "createdAt": 1 })

// 인덱스 확인
db.user_trajectories.getIndexes()
db.vqa_quizzes.getIndexes()
db.vqa_results.getIndexes()
```

### 샘플 문서 구조

```javascript
// user_trajectories
{
  "_id": ObjectId("..."),
  "userId": "user_123",
  "sessionId": "session_abc",
  "trajectory": {
    "events": [
      { "type": "click", "target": "button_1", "timestamp": 1234567890 },
      { "type": "scroll", "position": 500, "timestamp": 1234567891 }
    ],
    "metadata": {
      "browser": "Chrome",
      "device": "desktop"
    }
  },
  "createdAt": ISODate("2024-01-15T10:30:00Z")
}

// vqa_quizzes
{
  "_id": ObjectId("..."),
  "quizId": "quiz_456",
  "userId": "user_123",
  "imageUrl": "s3://goormgb-ai-vqa-images-prod/quiz_456.jpg",
  "question": "이 이미지에서 좌석 번호는 무엇인가요?",
  "options": ["A-1", "A-2", "B-1", "B-2"],
  "correctAnswer": "A-1",
  "createdAt": ISODate("2024-01-15T10:30:00Z")
}

// vqa_results
{
  "_id": ObjectId("..."),
  "resultId": "result_789",
  "userId": "user_123",
  "quizId": "quiz_456",
  "userAnswer": "A-1",
  "isCorrect": true,
  "responseTimeMs": 2500,
  "createdAt": ISODate("2024-01-15T10:30:00Z")
}
```

## 애플리케이션 연결 (Python/FastAPI)

### 의존성 설치

```bash
pip install motor pymongo
```

### 연결 코드

```python
# app/db/mongodb.py
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi
import os

MONGODB_URI = os.getenv("MONGODB_URI")

class MongoDB:
    client: AsyncIOMotorClient = None
    db = None

mongodb = MongoDB()

async def connect_to_mongo():
    mongodb.client = AsyncIOMotorClient(
        MONGODB_URI,
        server_api=ServerApi('1')
    )
    mongodb.db = mongodb.client.goormgb

    # 연결 테스트
    await mongodb.client.admin.command('ping')
    print("MongoDB Atlas 연결 성공!")

async def close_mongo_connection():
    if mongodb.client:
        mongodb.client.close()

# 컬렉션 접근
def get_trajectories_collection():
    return mongodb.db.user_trajectories

def get_vqa_quizzes_collection():
    return mongodb.db.vqa_quizzes

def get_vqa_results_collection():
    return mongodb.db.vqa_results
```

### 사용 예시

```python
# app/services/trajectory_service.py
from datetime import datetime
from app.db.mongodb import get_trajectories_collection

async def save_trajectory(user_id: str, session_id: str, trajectory: dict):
    collection = get_trajectories_collection()

    doc = {
        "userId": user_id,
        "sessionId": session_id,
        "trajectory": trajectory,
        "createdAt": datetime.utcnow()  # TTL 기준 필드
    }

    result = await collection.insert_one(doc)
    return str(result.inserted_id)

async def get_user_trajectories(user_id: str, limit: int = 100):
    collection = get_trajectories_collection()

    cursor = collection.find(
        {"userId": user_id}
    ).sort("createdAt", -1).limit(limit)

    return await cursor.to_list(length=limit)
```

## 환경 변수 설정

### 로컬 개발 (.env)

```bash
MONGODB_URI=mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/?retryWrites=true&w=majority
MONGODB_DATABASE=goormgb
```

### AWS Secrets Manager

```bash
# Secrets Manager에 저장
aws secretsmanager create-secret \
  --name goormgb/ai/mongodb \
  --secret-string '{"uri":"mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/?retryWrites=true&w=majority"}'
```

## 모니터링

### Atlas 대시보드

- Clusters → Metrics 탭에서 확인
- 주요 지표:
  - Connections
  - Operations
  - Data Size
  - Network I/O

### 용량 모니터링

```javascript
// MongoDB Shell에서 용량 확인
use goormgb
db.stats()

// 컬렉션별 용량
db.user_trajectories.stats()
db.vqa_quizzes.stats()
```

## 비용 관리

### Free Tier 한도

| 항목 | 한도 |
|------|------|
| Storage | 512 MB |
| RAM | 512 MB (shared) |
| Connections | 500 |
| Network | 10 GB/월 |

### 용량 초과 시 대응

1. **TTL 기간 단축**: 7일 → 3일
2. **Flex 티어 업그레이드**: $8-30/월 (5GB)
3. **아카이브 주기 단축**: 매일 → 매 12시간

## 트러블슈팅

### 연결 실패

```bash
# IP 화이트리스트 확인
# Network Access → IP Access List

# 연결 테스트
mongosh "mongodb+srv://goormgb_ai:<password>@goormgb-ai.xxxxx.mongodb.net/test"
```

### TTL 인덱스 동작 확인

```javascript
// TTL 인덱스 확인
db.user_trajectories.getIndexes()

// TTL 스레드 상태 확인 (60초마다 실행)
db.adminCommand({ "serverStatus": 1 }).metrics.ttl
```

### 용량 확인

```javascript
// 전체 데이터베이스 크기
db.stats().dataSize / (1024 * 1024)  // MB

// 512MB 초과 시 알림 설정
// Atlas → Alerts → Create Alert → Data Size
```

## 다음 단계

1. [Lambda 백업 함수 설정](./LAMBDA_BACKUP.md)
2. [S3 아카이브 정책](./S3_LIFECYCLE.md)
