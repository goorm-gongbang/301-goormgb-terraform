#!/bin/bash
# lambda/mongodb-backup/build.sh
# Lambda 배포 패키지 빌드 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_FILE="${SCRIPT_DIR}/mongodb-backup.zip"

echo "🔧 Lambda 패키지 빌드 시작..."

# 기존 빌드 정리
rm -rf "${BUILD_DIR}"
rm -f "${OUTPUT_FILE}"

# 빌드 디렉토리 생성
mkdir -p "${BUILD_DIR}"

# 의존성 설치 (Lambda 호환 환경)
echo "📦 의존성 설치 중..."
pip install \
  --target "${BUILD_DIR}" \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: \
  -r "${SCRIPT_DIR}/requirements.txt"

# 핸들러 복사
echo "📝 핸들러 복사 중..."
cp "${SCRIPT_DIR}/handler.py" "${BUILD_DIR}/"

# ZIP 패키지 생성
echo "📦 ZIP 패키지 생성 중..."
cd "${BUILD_DIR}"
zip -r "${OUTPUT_FILE}" .

# 정리
cd "${SCRIPT_DIR}"
rm -rf "${BUILD_DIR}"

# 결과 출력
ZIP_SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
echo ""
echo "✅ 빌드 완료!"
echo "   파일: ${OUTPUT_FILE}"
echo "   크기: ${ZIP_SIZE}"
echo ""
echo "📤 배포 명령어:"
echo "   aws lambda update-function-code \\"
echo "     --function-name goormgb-mongodb-backup-prod \\"
echo "     --zip-file fileb://${OUTPUT_FILE}"
