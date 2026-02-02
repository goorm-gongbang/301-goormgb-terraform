# S3 로그 버킷 가이드

## 개요

단기 프로젝트(3개월)에 최적화된 S3 로그 관리 전략입니다.
Glacier 전환 없이 **지정된 날짜에 자동 삭제(Expiration)**만 사용합니다.

---

## 버킷 구조

```
s3://goormgb-logs-prod/
├── ai-data/                    # 30일 후 삭제
│   └── {date}/
│       └── {filename}.json
│
├── infra/                      # 3일 후 삭제
│   ├── dev/
│   │   ├── istio/
│   │   ├── k8s/
│   │   └── loki/
│   └── prod/
│       └── ...
│
└── web/                        # 14일 후 삭제
    ├── dev/
    │   ├── fastapi/
    │   └── nextjs/
    └── prod/
        └── ...
```

---

## 수명주기 정책

| Prefix | 보관 기간 | 대상 서비스 | dev/prod 구분 |
|--------|-----------|-------------|---------------|
| `ai-data/` | 30일 | 마우스 궤적, 보안 퀴즈 | JSON 내 `env` 필드 |
| `infra/{env}/` | 3일 | Istio, K8s, Loki | prefix로 분리 |
| `web/{env}/` | 14일 | FastAPI, Next.js APM | prefix로 분리 |

### 왜 이렇게 나눴나?

- **AI 데이터 (30일)**: 모델 학습/검증에 한 달 내 데이터면 충분, 발표 직전 데이터가 중요
- **인프라 로그 (3일)**: 이슈 발생 즉시 해결해야 의미 있음, 용량 차지 방지
- **서비스 로그 (14일)**: 시나리오 테스트, 버그 리포트 확인에 2주면 충분

---

## AI 데이터 JSON 형식

dev/prod를 같이 저장하고, JSON 내 `env` 필드로 구분합니다.

```json
{
  "env": "dev",
  "label": "verified",
  "user_id": "wonny",
  "timestamp": "2026-02-02T12:00:00Z",
  "trajectory": [
    {"x": 100, "y": 200, "t": 0},
    {"x": 150, "y": 250, "t": 100}
  ]
}
```

### label 값

| label | 설명 |
|-------|------|
| `raw` | 원본 데이터 |
| `verified` | 검증된 학습용 데이터 |
| `training` | 학습에 사용된 데이터 |
| `test` | 테스트용 데이터 |

### 학습 스크립트에서 사용

```python
import boto3
import json

s3 = boto3.client('s3')
bucket = 'goormgb-logs-prod'

# prod의 verified 데이터만 가져오기
response = s3.list_objects_v2(Bucket=bucket, Prefix='ai-data/')
for obj in response.get('Contents', []):
    data = s3.get_object(Bucket=bucket, Key=obj['Key'])
    content = json.loads(data['Body'].read())

    if content.get('env') == 'prod' and content.get('label') == 'verified':
        # 학습 데이터로 사용
        process_trajectory(content['trajectory'])
```

---

## Dev 미니PC → S3 배치 업로드

미니PC 용량 관리를 위해 로그를 S3로 정기 업로드합니다.

### 배치 스크립트

```bash
#!/bin/bash
# /home/user/scripts/upload-logs-to-s3.sh

S3_BUCKET="goormgb-logs-prod"
LOG_BASE="/var/log"
DATE=$(date +%Y-%m-%d)

# 1. AI 데이터 업로드
if [ -d "$LOG_BASE/ai-data" ]; then
  aws s3 sync "$LOG_BASE/ai-data/" "s3://$S3_BUCKET/ai-data/$DATE/" \
    --exclude "*.tmp"

  # 업로드 성공 시 로컬 삭제 (7일 이상 된 파일)
  find "$LOG_BASE/ai-data" -type f -mtime +7 -delete
fi

# 2. 인프라 로그 업로드
for service in istio k8s loki; do
  if [ -d "$LOG_BASE/$service" ]; then
    aws s3 sync "$LOG_BASE/$service/" "s3://$S3_BUCKET/infra/dev/$service/$DATE/" \
      --exclude "*.tmp"

    # 1일 이상 된 파일 삭제 (S3에 3일 보관되므로)
    find "$LOG_BASE/$service" -type f -mtime +1 -delete
  fi
done

# 3. 웹 서비스 로그 업로드
for service in fastapi nextjs; do
  if [ -d "$LOG_BASE/$service" ]; then
    aws s3 sync "$LOG_BASE/$service/" "s3://$S3_BUCKET/web/dev/$service/$DATE/" \
      --exclude "*.tmp"

    # 3일 이상 된 파일 삭제 (S3에 14일 보관되므로)
    find "$LOG_BASE/$service" -type f -mtime +3 -delete
  fi
done

echo "[$(date)] Log upload completed"
```

### Cron 설정

```bash
# 매일 새벽 3시에 실행
crontab -e

# 추가할 내용
0 3 * * * /home/user/scripts/upload-logs-to-s3.sh >> /var/log/s3-upload.log 2>&1
```

### Systemd Timer (권장)

```ini
# /etc/systemd/system/s3-log-upload.service
[Unit]
Description=Upload logs to S3
After=network.target

[Service]
Type=oneshot
ExecStart=/home/user/scripts/upload-logs-to-s3.sh
User=root

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/s3-log-upload.timer
[Unit]
Description=Run S3 log upload daily

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# 활성화
sudo systemctl enable s3-log-upload.timer
sudo systemctl start s3-log-upload.timer

# 상태 확인
systemctl list-timers | grep s3
```

---

## 미니PC 용량 관리 팁

### 1. 로그 로테이션 설정

```bash
# /etc/logrotate.d/app-logs
/var/log/fastapi/*.log
/var/log/ai-data/*.json {
    daily
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

### 2. Docker 로그 제한

```yaml
# docker-compose.yml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 3. K3s 로그 제한

```bash
# /etc/rancher/k3s/config.yaml
kubelet-arg:
  - "container-log-max-files=3"
  - "container-log-max-size=10Mi"
```

---

## S3 경로 규칙

### 업로드 시 경로

| 환경 | 카테고리 | S3 경로 |
|------|----------|---------|
| dev | AI 데이터 | `ai-data/{date}/{filename}.json` |
| dev | Istio | `infra/dev/istio/{date}/{filename}` |
| dev | K8s | `infra/dev/k8s/{date}/{filename}` |
| dev | FastAPI | `web/dev/fastapi/{date}/{filename}` |
| prod | AI 데이터 | `ai-data/{date}/{filename}.json` |
| prod | Istio | `infra/prod/istio/{date}/{filename}` |
| prod | FastAPI | `web/prod/fastapi/{date}/{filename}` |

### 파일명 규칙

```
# AI 데이터
trajectory_{user_id}_{timestamp}.json
quiz_{user_id}_{timestamp}.json

# 인프라 로그
istio-proxy_{pod_name}_{timestamp}.log
kube-apiserver_{timestamp}.log

# 웹 서비스 로그
fastapi_{service_name}_{timestamp}.log
nextjs_access_{timestamp}.log
```

---

## 관련 파일

| 파일 | 설명 |
|------|------|
| `modules/s3/main.tf` | S3 버킷 및 수명주기 정책 |
| `scripts/upload-logs-to-s3.sh` | 배치 업로드 스크립트 (생성 필요) |

---

## 프로젝트 종료 후

프로젝트 종료 시 `Project=goormgb` 태그가 달린 S3 버킷을 한 번에 삭제할 수 있습니다.

```bash
# 버킷 내용 삭제 후 버킷 삭제
aws s3 rb s3://goormgb-logs-prod --force
```
