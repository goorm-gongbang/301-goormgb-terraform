# lambda/mongodb-backup/handler.py
"""
MongoDB Atlas → S3 Backup Lambda

TTL로 삭제되기 전에 데이터를 S3에 아카이브합니다.
매일 새벽 3시(KST)에 실행됩니다.
"""

import os
import json
import gzip
import boto3
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import json_util

# 환경 변수
MONGODB_SECRET_ARN = os.environ.get("MONGODB_SECRET_ARN")
TRAJECTORY_BUCKET = os.environ.get("TRAJECTORY_BUCKET")
VQA_DATA_BUCKET = os.environ.get("VQA_DATA_BUCKET")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")
TRAJECTORY_TTL_DAYS = int(os.environ.get("TRAJECTORY_TTL_DAYS", 7))
VQA_TTL_DAYS = int(os.environ.get("VQA_TTL_DAYS", 30))

# AWS 클라이언트
secrets_client = boto3.client("secretsmanager")
s3_client = boto3.client("s3")


def get_mongodb_uri():
    """Secrets Manager에서 MongoDB URI 조회"""
    response = secrets_client.get_secret_value(SecretId=MONGODB_SECRET_ARN)
    secret = json.loads(response["SecretString"])
    return secret.get("uri") or secret.get("MONGODB_URI")


def backup_collection(db, collection_name: str, bucket: str, ttl_days: int):
    """
    컬렉션 데이터를 S3에 백업

    TTL 만료 1일 전 데이터를 백업합니다.
    예: TTL 7일인 경우, 6-7일 된 데이터를 백업
    """
    collection = db[collection_name]

    # TTL 만료 1일 전 ~ 당일 데이터 조회
    # (오늘 백업하지 않으면 내일 TTL로 삭제됨)
    now = datetime.utcnow()
    expire_start = now - timedelta(days=ttl_days)
    expire_end = now - timedelta(days=ttl_days - 1)

    query = {
        "createdAt": {
            "$gte": expire_start,
            "$lt": expire_end
        }
    }

    # 데이터 조회
    documents = list(collection.find(query))

    if not documents:
        print(f"[{collection_name}] 백업할 데이터 없음 (기간: {expire_start} ~ {expire_end})")
        return 0

    # JSON으로 직렬화 (BSON 타입 처리)
    json_data = json.dumps(
        documents,
        default=json_util.default,
        ensure_ascii=False
    )

    # GZIP 압축
    compressed = gzip.compress(json_data.encode("utf-8"))

    # S3 키 생성: collection/YYYY/MM/DD/HHmmss.json.gz
    date_prefix = now.strftime("%Y/%m/%d")
    timestamp = now.strftime("%H%M%S")
    s3_key = f"{collection_name}/{date_prefix}/{timestamp}.json.gz"

    # S3 업로드
    s3_client.put_object(
        Bucket=bucket,
        Key=s3_key,
        Body=compressed,
        ContentType="application/gzip",
        Metadata={
            "collection": collection_name,
            "document_count": str(len(documents)),
            "date_range_start": expire_start.isoformat(),
            "date_range_end": expire_end.isoformat(),
            "environment": ENVIRONMENT
        }
    )

    print(f"[{collection_name}] {len(documents)}개 문서 백업 완료 → s3://{bucket}/{s3_key}")
    return len(documents)


def lambda_handler(event, context):
    """Lambda 핸들러"""
    print(f"MongoDB Backup 시작 - 환경: {ENVIRONMENT}")
    print(f"Trajectory TTL: {TRAJECTORY_TTL_DAYS}일, VQA TTL: {VQA_TTL_DAYS}일")

    # MongoDB 연결
    mongodb_uri = get_mongodb_uri()
    client = MongoClient(mongodb_uri)
    db = client.goormgb

    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "environment": ENVIRONMENT,
        "backups": []
    }

    try:
        # 1. 궤적 데이터 백업
        trajectory_count = backup_collection(
            db=db,
            collection_name="user_trajectories",
            bucket=TRAJECTORY_BUCKET,
            ttl_days=TRAJECTORY_TTL_DAYS
        )
        results["backups"].append({
            "collection": "user_trajectories",
            "bucket": TRAJECTORY_BUCKET,
            "document_count": trajectory_count
        })

        # 2. VQA 퀴즈 데이터 백업
        vqa_quiz_count = backup_collection(
            db=db,
            collection_name="vqa_quizzes",
            bucket=VQA_DATA_BUCKET,
            ttl_days=VQA_TTL_DAYS
        )
        results["backups"].append({
            "collection": "vqa_quizzes",
            "bucket": VQA_DATA_BUCKET,
            "document_count": vqa_quiz_count
        })

        # 3. VQA 결과 데이터 백업 (TTL 없음 - 전날 데이터만)
        # TTL이 없으므로 매일 새로운 데이터만 백업
        yesterday = datetime.utcnow() - timedelta(days=1)
        today = datetime.utcnow()

        vqa_results = list(db.vqa_results.find({
            "createdAt": {
                "$gte": yesterday.replace(hour=0, minute=0, second=0),
                "$lt": today.replace(hour=0, minute=0, second=0)
            }
        }))

        if vqa_results:
            json_data = json.dumps(vqa_results, default=json_util.default, ensure_ascii=False)
            compressed = gzip.compress(json_data.encode("utf-8"))

            date_prefix = yesterday.strftime("%Y/%m/%d")
            s3_key = f"vqa_results/{date_prefix}/daily.json.gz"

            s3_client.put_object(
                Bucket=VQA_DATA_BUCKET,
                Key=s3_key,
                Body=compressed,
                ContentType="application/gzip"
            )

            print(f"[vqa_results] {len(vqa_results)}개 문서 백업 완료")
            results["backups"].append({
                "collection": "vqa_results",
                "bucket": VQA_DATA_BUCKET,
                "document_count": len(vqa_results)
            })

        results["status"] = "success"

    except Exception as e:
        print(f"백업 실패: {str(e)}")
        results["status"] = "error"
        results["error"] = str(e)
        raise

    finally:
        client.close()

    print(f"백업 완료: {json.dumps(results, indent=2)}")
    return results
