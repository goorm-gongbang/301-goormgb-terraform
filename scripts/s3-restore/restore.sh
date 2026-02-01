#!/bin/bash
# scripts/s3-restore/restore.sh
# S3 아카이브 → MongoDB 복원 래퍼 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"

#------------------------------------------------------------------------------
# 색상 정의
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

#------------------------------------------------------------------------------
# 도움말
#------------------------------------------------------------------------------
show_help() {
    cat << EOF
사용법: $0 [옵션]

S3 아카이브 데이터를 MongoDB로 복원합니다.

옵션:
    --date DATE           복원할 날짜 (YYYY-MM-DD)
    --start-date DATE     시작 날짜 (범위 복원)
    --end-date DATE       종료 날짜 (범위 복원)
    --collection NAME     컬렉션 이름 (user_trajectories, vqa_quizzes, vqa_results)
    --target-collection   복원 대상 컬렉션 이름
    --bucket NAME         S3 버킷 (기본: 자동 선택)
    --database NAME       MongoDB 데이터베이스 (기본: goormgb)
    --dry-run             파일 목록만 확인
    --setup               가상환경 설정만 수행
    -h, --help            도움말 표시

환경변수:
    MONGODB_URI           MongoDB 연결 문자열 (필수)
    AWS_ACCESS_KEY_ID     AWS 액세스 키
    AWS_SECRET_ACCESS_KEY AWS 시크릿 키

예시:
    # 특정 날짜 복원
    $0 --date 2024-01-15 --collection user_trajectories

    # 날짜 범위 복원
    $0 --start-date 2024-01-01 --end-date 2024-01-31 --collection user_trajectories

    # VQA 데이터 복원 (커스텀 컬렉션 이름)
    $0 --date 2024-01-15 --collection vqa_quizzes --target-collection vqa_jan15

    # 파일 목록만 확인
    $0 --date 2024-01-15 --collection user_trajectories --dry-run

EOF
}

#------------------------------------------------------------------------------
# 가상환경 설정
#------------------------------------------------------------------------------
setup_venv() {
    log "가상환경 설정 중..."

    # Python 확인
    if ! command -v python3 &> /dev/null; then
        error "python3이 설치되어 있지 않습니다"
    fi

    # 가상환경 생성
    if [[ ! -d "$VENV_DIR" ]]; then
        log "가상환경 생성: $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi

    # 활성화
    source "${VENV_DIR}/bin/activate"

    # 의존성 설치
    log "의존성 설치 중..."
    pip install -q -r "${SCRIPT_DIR}/requirements.txt"

    log "가상환경 설정 완료"
}

#------------------------------------------------------------------------------
# 환경변수 확인
#------------------------------------------------------------------------------
check_env() {
    if [[ -z "$MONGODB_URI" ]]; then
        error "MONGODB_URI 환경변수를 설정해주세요"
    fi

    if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        warn "AWS 자격 증명이 설정되지 않았습니다. ~/.aws/credentials 사용 시도..."
    fi
}

#------------------------------------------------------------------------------
# 메인
#------------------------------------------------------------------------------
main() {
    # 인자 없으면 도움말 표시
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    # --help 처리
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    # --setup 처리
    if [[ "$1" == "--setup" ]]; then
        setup_venv
        log "설정 완료! 이제 복원 명령을 실행하세요."
        exit 0
    fi

    # 환경변수 확인
    check_env

    # 가상환경 설정/활성화
    setup_venv

    # Python 스크립트 실행
    log "복원 스크립트 실행..."
    python3 "${SCRIPT_DIR}/restore.py" "$@"
}

main "$@"
