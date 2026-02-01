#!/bin/bash
# scripts/migrate-policies.sh
# Dev PostgreSQL → Prod RDS 정책 데이터 마이그레이션

set -e

#------------------------------------------------------------------------------
# 설정
#------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUMP_DIR="${SCRIPT_DIR}/../data/migrations"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="${DUMP_DIR}/policies_${TIMESTAMP}.sql"

# Dev 환경 (미니PC k3s)
DEV_NAMESPACE="db"
DEV_POD="postgres-0"
DEV_USER="goormgb"
DEV_DB="goormgb_ai"

# Prod 환경 (AWS RDS) - 환경변수로 설정
PROD_HOST="${RDS_HOST:-}"
PROD_USER="${RDS_USER:-goormgb}"
PROD_DB="${RDS_DB:-goormgb_ai}"
PROD_PASSWORD="${RDS_PASSWORD:-}"

# 마이그레이션 대상 테이블
TABLES=(
    "policies"
    "policy_versions"
    "risk_rules"
    "macro_patterns"
)

#------------------------------------------------------------------------------
# 함수
#------------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_requirements() {
    log "요구사항 확인 중..."

    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        error "kubectl이 설치되어 있지 않습니다"
    fi

    # psql 확인
    if ! command -v psql &> /dev/null; then
        error "psql이 설치되어 있지 않습니다"
    fi

    # Prod 환경변수 확인
    if [[ -z "$PROD_HOST" ]]; then
        error "RDS_HOST 환경변수가 설정되지 않았습니다"
    fi

    if [[ -z "$PROD_PASSWORD" ]]; then
        error "RDS_PASSWORD 환경변수가 설정되지 않았습니다"
    fi

    log "요구사항 확인 완료"
}

create_dump_dir() {
    if [[ ! -d "$DUMP_DIR" ]]; then
        log "덤프 디렉토리 생성: $DUMP_DIR"
        mkdir -p "$DUMP_DIR"
    fi
}

export_from_dev() {
    log "=== Dev PostgreSQL에서 데이터 내보내기 ==="

    # k3s 컨텍스트 확인
    if ! kubectl get pod "$DEV_POD" -n "$DEV_NAMESPACE" &> /dev/null; then
        error "Dev PostgreSQL Pod를 찾을 수 없습니다: $DEV_POD"
    fi

    # 테이블 목록을 pg_dump 옵션으로 변환
    TABLE_OPTS=""
    for table in "${TABLES[@]}"; do
        TABLE_OPTS="$TABLE_OPTS -t $table"
    done

    log "내보내는 테이블: ${TABLES[*]}"

    # pg_dump 실행
    kubectl exec -n "$DEV_NAMESPACE" "$DEV_POD" -- \
        pg_dump -U "$DEV_USER" -d "$DEV_DB" \
        $TABLE_OPTS \
        --no-owner \
        --no-privileges \
        --if-exists \
        --clean \
        > "$DUMP_FILE"

    # 덤프 파일 확인
    if [[ ! -s "$DUMP_FILE" ]]; then
        error "덤프 파일이 비어있습니다"
    fi

    DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
    log "덤프 완료: $DUMP_FILE ($DUMP_SIZE)"
}

import_to_prod() {
    log "=== Prod RDS에 데이터 가져오기 ==="

    # RDS 연결 테스트
    log "RDS 연결 테스트 중..."
    if ! PGPASSWORD="$PROD_PASSWORD" psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" -c "SELECT 1" &> /dev/null; then
        error "RDS 연결 실패"
    fi

    log "RDS 연결 성공"

    # 데이터 가져오기
    log "데이터 가져오기 중..."
    PGPASSWORD="$PROD_PASSWORD" psql \
        -h "$PROD_HOST" \
        -U "$PROD_USER" \
        -d "$PROD_DB" \
        -f "$DUMP_FILE"

    log "데이터 가져오기 완료"
}

verify_migration() {
    log "=== 마이그레이션 검증 ==="

    for table in "${TABLES[@]}"; do
        # Dev 카운트
        DEV_COUNT=$(kubectl exec -n "$DEV_NAMESPACE" "$DEV_POD" -- \
            psql -U "$DEV_USER" -d "$DEV_DB" -t -c "SELECT COUNT(*) FROM $table" 2>/dev/null | tr -d ' ')

        # Prod 카운트
        PROD_COUNT=$(PGPASSWORD="$PROD_PASSWORD" psql \
            -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" \
            -t -c "SELECT COUNT(*) FROM $table" 2>/dev/null | tr -d ' ')

        if [[ "$DEV_COUNT" == "$PROD_COUNT" ]]; then
            log "✅ $table: $DEV_COUNT rows (일치)"
        else
            log "⚠️  $table: Dev=$DEV_COUNT, Prod=$PROD_COUNT (불일치)"
        fi
    done
}

#------------------------------------------------------------------------------
# 메인
#------------------------------------------------------------------------------
main() {
    log "=========================================="
    log "PostgreSQL 정책 마이그레이션 시작"
    log "=========================================="

    check_requirements
    create_dump_dir
    export_from_dev
    import_to_prod
    verify_migration

    log "=========================================="
    log "마이그레이션 완료!"
    log "덤프 파일: $DUMP_FILE"
    log "=========================================="
}

# 도움말
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << EOF
사용법: $0

Dev PostgreSQL (미니PC k3s)에서 Prod RDS로 정책 데이터를 마이그레이션합니다.

필수 환경변수:
  RDS_HOST      Prod RDS 호스트
  RDS_PASSWORD  Prod RDS 비밀번호

선택 환경변수:
  RDS_USER      Prod RDS 사용자 (기본: goormgb)
  RDS_DB        Prod RDS 데이터베이스 (기본: goormgb_ai)

예시:
  export RDS_HOST=goormgb-prod.xxxxx.ap-northeast-2.rds.amazonaws.com
  export RDS_PASSWORD=your_password
  $0

EOF
    exit 0
fi

main
