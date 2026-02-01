#!/usr/bin/env python3
# scripts/s3-restore/restore.py
"""
S3 아카이브 → MongoDB 복원 스크립트

사용법:
    # 특정 날짜 복원
    ./restore.py --date 2024-01-15 --collection user_trajectories

    # 날짜 범위 복원
    ./restore.py --start-date 2024-01-01 --end-date 2024-01-31 --collection user_trajectories

    # 다른 컬렉션 이름으로 복원
    ./restore.py --date 2024-01-15 --collection user_trajectories --target-collection restored_jan15
"""

import os
import sys
import gzip
import json
import argparse
import boto3
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import json_util

#------------------------------------------------------------------------------
# 설정
#------------------------------------------------------------------------------
# 환경변수에서 읽기
MONGODB_URI = os.environ.get('MONGODB_URI')
AWS_REGION = os.environ.get('AWS_REGION', 'ap-northeast-2')

# 버킷 매핑
BUCKET_MAP = {
    'user_trajectories': 'goormgb-ai-trajectory-prod',
    'vqa_quizzes': 'goormgb-ai-vqa-data-prod',
    'vqa_results': 'goormgb-ai-vqa-data-prod',
}

# S3 경로 매핑 (컬렉션 → S3 prefix)
PREFIX_MAP = {
    'user_trajectories': 'user_trajectories',
    'vqa_quizzes': 'vqa_quizzes',
    'vqa_results': 'vqa_results',
}

#------------------------------------------------------------------------------
# 유틸리티
#------------------------------------------------------------------------------
def log(message: str):
    """로그 출력"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")


def error(message: str):
    """에러 출력 후 종료"""
    log(f"ERROR: {message}")
    sys.exit(1)


def parse_date(date_str: str) -> datetime:
    """날짜 문자열 파싱"""
    try:
        return datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        error(f"잘못된 날짜 형식: {date_str} (예: 2024-01-15)")


#------------------------------------------------------------------------------
# S3 작업
#------------------------------------------------------------------------------
def get_s3_client():
    """S3 클라이언트 생성"""
    return boto3.client('s3', region_name=AWS_REGION)


def list_archive_files(s3_client, bucket: str, prefix: str, date: datetime) -> list:
    """특정 날짜의 아카이브 파일 목록 조회"""
    date_prefix = f"{prefix}/{date.strftime('%Y/%m/%d')}/"

    try:
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=date_prefix)
        files = [obj['Key'] for obj in response.get('Contents', [])]
        return files
    except Exception as e:
        log(f"경고: {date_prefix} 조회 실패 - {e}")
        return []


def download_and_parse(s3_client, bucket: str, key: str) -> list:
    """S3 파일 다운로드 및 JSON 파싱"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = gzip.decompress(response['Body'].read())
        # BSON 타입 지원하는 json_util 사용
        data = json.loads(content, object_hook=json_util.object_hook)
        return data
    except Exception as e:
        log(f"경고: {key} 다운로드 실패 - {e}")
        return []


#------------------------------------------------------------------------------
# MongoDB 작업
#------------------------------------------------------------------------------
def get_mongo_client():
    """MongoDB 클라이언트 생성"""
    if not MONGODB_URI:
        error("MONGODB_URI 환경변수가 설정되지 않았습니다")

    return MongoClient(MONGODB_URI)


def restore_to_mongodb(client, database: str, collection: str, documents: list) -> int:
    """MongoDB에 문서 복원"""
    if not documents:
        return 0

    db = client[database]
    coll = db[collection]

    # 중복 방지를 위해 _id 기준으로 upsert
    inserted = 0
    for doc in documents:
        try:
            # _id가 있으면 upsert, 없으면 insert
            if '_id' in doc:
                coll.replace_one({'_id': doc['_id']}, doc, upsert=True)
            else:
                coll.insert_one(doc)
            inserted += 1
        except Exception as e:
            log(f"경고: 문서 삽입 실패 - {e}")

    return inserted


#------------------------------------------------------------------------------
# 메인 로직
#------------------------------------------------------------------------------
def restore_single_date(
    s3_client,
    mongo_client,
    bucket: str,
    prefix: str,
    date: datetime,
    database: str,
    target_collection: str
) -> int:
    """단일 날짜 복원"""
    log(f"복원 시작: {date.strftime('%Y-%m-%d')}")

    # S3 파일 목록 조회
    files = list_archive_files(s3_client, bucket, prefix, date)

    if not files:
        log(f"  {date.strftime('%Y-%m-%d')}: 파일 없음")
        return 0

    total_restored = 0

    for file_key in files:
        log(f"  다운로드: {file_key}")

        # S3에서 다운로드 및 파싱
        documents = download_and_parse(s3_client, bucket, file_key)

        if documents:
            # MongoDB에 복원
            restored = restore_to_mongodb(mongo_client, database, target_collection, documents)
            total_restored += restored
            log(f"  복원: {restored}개 문서")

    return total_restored


def restore_date_range(
    s3_client,
    mongo_client,
    bucket: str,
    prefix: str,
    start_date: datetime,
    end_date: datetime,
    database: str,
    target_collection: str
) -> int:
    """날짜 범위 복원"""
    total = 0
    current = start_date

    while current <= end_date:
        count = restore_single_date(
            s3_client, mongo_client, bucket, prefix,
            current, database, target_collection
        )
        total += count
        current += timedelta(days=1)

    return total


#------------------------------------------------------------------------------
# CLI
#------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description='S3 아카이브 → MongoDB 복원',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
    # 특정 날짜 복원
    %(prog)s --date 2024-01-15 --collection user_trajectories

    # 날짜 범위 복원
    %(prog)s --start-date 2024-01-01 --end-date 2024-01-31 --collection user_trajectories

    # 커스텀 버킷 사용
    %(prog)s --date 2024-01-15 --bucket my-bucket --collection user_trajectories

환경변수:
    MONGODB_URI          MongoDB 연결 문자열 (필수)
    AWS_ACCESS_KEY_ID    AWS 액세스 키
    AWS_SECRET_ACCESS_KEY AWS 시크릿 키
    AWS_REGION           AWS 리전 (기본: ap-northeast-2)
        """
    )

    # 날짜 옵션
    date_group = parser.add_mutually_exclusive_group(required=True)
    date_group.add_argument('--date', help='복원할 날짜 (YYYY-MM-DD)')
    date_group.add_argument('--start-date', help='시작 날짜 (범위 복원)')

    parser.add_argument('--end-date', help='종료 날짜 (범위 복원, --start-date와 함께 사용)')

    # 컬렉션 옵션
    parser.add_argument(
        '--collection', '-c',
        required=True,
        choices=['user_trajectories', 'vqa_quizzes', 'vqa_results'],
        help='복원할 컬렉션'
    )

    parser.add_argument(
        '--target-collection', '-t',
        help='복원 대상 컬렉션 이름 (기본: {collection}_restored)'
    )

    # 기타 옵션
    parser.add_argument('--bucket', '-b', help='S3 버킷 이름 (기본: 자동 매핑)')
    parser.add_argument('--database', '-d', default='goormgb', help='MongoDB 데이터베이스 (기본: goormgb)')
    parser.add_argument('--dry-run', action='store_true', help='실제 복원 없이 파일 목록만 확인')

    args = parser.parse_args()

    # 날짜 파싱
    if args.date:
        start_date = end_date = parse_date(args.date)
    else:
        start_date = parse_date(args.start_date)
        if args.end_date:
            end_date = parse_date(args.end_date)
        else:
            error("--start-date 사용 시 --end-date도 필요합니다")

    # 버킷 결정
    bucket = args.bucket or BUCKET_MAP.get(args.collection)
    if not bucket:
        error(f"알 수 없는 컬렉션: {args.collection}")

    # S3 prefix 결정
    prefix = PREFIX_MAP.get(args.collection, args.collection)

    # 대상 컬렉션 결정
    target_collection = args.target_collection or f"{args.collection}_restored"

    # 로그 출력
    log("=" * 60)
    log("S3 아카이브 → MongoDB 복원")
    log("=" * 60)
    log(f"S3 버킷: {bucket}")
    log(f"S3 prefix: {prefix}")
    log(f"날짜 범위: {start_date.strftime('%Y-%m-%d')} ~ {end_date.strftime('%Y-%m-%d')}")
    log(f"대상 컬렉션: {args.database}.{target_collection}")
    log("=" * 60)

    if args.dry_run:
        log("DRY RUN 모드 - 실제 복원하지 않습니다")
        s3_client = get_s3_client()
        current = start_date
        while current <= end_date:
            files = list_archive_files(s3_client, bucket, prefix, current)
            for f in files:
                log(f"  {f}")
            current += timedelta(days=1)
        return

    # 클라이언트 초기화
    s3_client = get_s3_client()
    mongo_client = get_mongo_client()

    # 연결 테스트
    try:
        mongo_client.admin.command('ping')
        log("MongoDB 연결 성공")
    except Exception as e:
        error(f"MongoDB 연결 실패: {e}")

    # 복원 실행
    total = restore_date_range(
        s3_client, mongo_client,
        bucket, prefix,
        start_date, end_date,
        args.database, target_collection
    )

    log("=" * 60)
    log(f"복원 완료: 총 {total}개 문서")
    log(f"컬렉션: {args.database}.{target_collection}")
    log("=" * 60)

    # 정리
    mongo_client.close()


if __name__ == '__main__':
    main()
