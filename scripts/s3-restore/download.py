#!/usr/bin/env python3
# scripts/s3-restore/download.py
"""
S3 아카이브 → 로컬 파일 다운로드 스크립트

MongoDB 복원 없이 로컬에 JSON 파일로 다운로드합니다.
Colab, Jupyter 등에서 분석용으로 사용합니다.

사용법:
    # 특정 날짜 다운로드
    ./download.py --date 2024-01-15 --collection user_trajectories --output ./data/

    # 날짜 범위 다운로드
    ./download.py --start-date 2024-01-01 --end-date 2024-01-31 --collection user_trajectories
"""

import os
import sys
import gzip
import json
import argparse
import boto3
from datetime import datetime, timedelta
from pathlib import Path

#------------------------------------------------------------------------------
# 설정
#------------------------------------------------------------------------------
AWS_REGION = os.environ.get('AWS_REGION', 'ap-northeast-2')

BUCKET_MAP = {
    'user_trajectories': 'goormgb-ai-trajectory-prod',
    'vqa_quizzes': 'goormgb-ai-vqa-data-prod',
    'vqa_results': 'goormgb-ai-vqa-data-prod',
}

PREFIX_MAP = {
    'user_trajectories': 'user_trajectories',
    'vqa_quizzes': 'vqa_quizzes',
    'vqa_results': 'vqa_results',
}

#------------------------------------------------------------------------------
# 유틸리티
#------------------------------------------------------------------------------
def log(message: str):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")


def error(message: str):
    log(f"ERROR: {message}")
    sys.exit(1)


def parse_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        error(f"잘못된 날짜 형식: {date_str}")


#------------------------------------------------------------------------------
# S3 작업
#------------------------------------------------------------------------------
def download_archive(
    s3_client,
    bucket: str,
    prefix: str,
    start_date: datetime,
    end_date: datetime,
    output_dir: Path,
    merge: bool = False
) -> dict:
    """S3 아카이브 다운로드"""

    output_dir.mkdir(parents=True, exist_ok=True)
    stats = {'files': 0, 'records': 0, 'bytes': 0}
    all_data = []

    current = start_date
    while current <= end_date:
        date_prefix = f"{prefix}/{current.strftime('%Y/%m/%d')}/"

        try:
            response = s3_client.list_objects_v2(Bucket=bucket, Prefix=date_prefix)

            for obj in response.get('Contents', []):
                key = obj['Key']
                log(f"다운로드: s3://{bucket}/{key}")

                # S3에서 다운로드
                s3_response = s3_client.get_object(Bucket=bucket, Key=key)
                content = gzip.decompress(s3_response['Body'].read())
                data = json.loads(content)

                stats['files'] += 1
                stats['records'] += len(data)
                stats['bytes'] += len(content)

                if merge:
                    all_data.extend(data)
                else:
                    # 개별 파일로 저장
                    date_str = current.strftime('%Y-%m-%d')
                    filename = f"{prefix}_{date_str}.json"
                    output_path = output_dir / filename

                    with open(output_path, 'w', encoding='utf-8') as f:
                        json.dump(data, f, ensure_ascii=False, indent=2, default=str)

                    log(f"  저장: {output_path} ({len(data)}개 레코드)")

        except Exception as e:
            log(f"경고: {date_prefix} 처리 실패 - {e}")

        current += timedelta(days=1)

    # 병합 모드일 경우 하나의 파일로 저장
    if merge and all_data:
        date_range = f"{start_date.strftime('%Y%m%d')}-{end_date.strftime('%Y%m%d')}"
        filename = f"{prefix}_{date_range}_merged.json"
        output_path = output_dir / filename

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(all_data, f, ensure_ascii=False, indent=2, default=str)

        log(f"병합 저장: {output_path} ({len(all_data)}개 레코드)")

    return stats


#------------------------------------------------------------------------------
# CLI
#------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description='S3 아카이브 → 로컬 파일 다운로드',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    date_group = parser.add_mutually_exclusive_group(required=True)
    date_group.add_argument('--date', help='다운로드할 날짜 (YYYY-MM-DD)')
    date_group.add_argument('--start-date', help='시작 날짜')

    parser.add_argument('--end-date', help='종료 날짜')
    parser.add_argument(
        '--collection', '-c',
        required=True,
        choices=['user_trajectories', 'vqa_quizzes', 'vqa_results'],
        help='컬렉션'
    )
    parser.add_argument('--output', '-o', default='./data', help='출력 디렉토리')
    parser.add_argument('--bucket', '-b', help='S3 버킷')
    parser.add_argument('--merge', '-m', action='store_true', help='하나의 파일로 병합')

    args = parser.parse_args()

    # 날짜 파싱
    if args.date:
        start_date = end_date = parse_date(args.date)
    else:
        start_date = parse_date(args.start_date)
        end_date = parse_date(args.end_date) if args.end_date else start_date

    bucket = args.bucket or BUCKET_MAP.get(args.collection)
    prefix = PREFIX_MAP.get(args.collection, args.collection)
    output_dir = Path(args.output)

    log("=" * 60)
    log("S3 아카이브 다운로드")
    log("=" * 60)
    log(f"버킷: {bucket}")
    log(f"컬렉션: {args.collection}")
    log(f"날짜: {start_date.strftime('%Y-%m-%d')} ~ {end_date.strftime('%Y-%m-%d')}")
    log(f"출력: {output_dir}")
    log(f"병합: {'예' if args.merge else '아니오'}")
    log("=" * 60)

    s3_client = boto3.client('s3', region_name=AWS_REGION)

    stats = download_archive(
        s3_client, bucket, prefix,
        start_date, end_date,
        output_dir, args.merge
    )

    log("=" * 60)
    log(f"완료: {stats['files']}개 파일, {stats['records']}개 레코드")
    log(f"용량: {stats['bytes'] / 1024 / 1024:.2f} MB")
    log("=" * 60)


if __name__ == '__main__':
    main()
