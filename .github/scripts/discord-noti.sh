#!/bin/bash

# 1. 필수 변수 체크
if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set."
  exit 1
fi

# 2. 결과 파일이 없으면 처리
if [ ! -f "$RESULT_FILE" ]; then
  RESULT_CONTENT="결과 파일을 찾을 수 없습니다."
  BLOCK_FMT="text"
else
  # ------------------------------------------------------------------
  # 핵심 로직: 로그에서 순수한 텍스트만 추출 (포맷팅 태그 제거)
  # ------------------------------------------------------------------

  # A. 실패(Failure)한 경우
  if [ "$STATUS" != "success" ]; then
    EXTRACTED=$(grep "Error:" "$RESULT_FILE" | head -n 1)
    if [ -z "$EXTRACTED" ]; then
      EXTRACTED=$(tail -n 3 "$RESULT_FILE")
    fi
    RESULT_CONTENT="🚫 오류 발생: $EXTRACTED"
    BLOCK_FMT="text"

  # B. 성공(Success)한 경우
  else
    if [ "$NOTIFY_TYPE" == "plan" ]; then
      # Case 1: 변경 사항이 있는 경우
      PLAN_LINE=$(grep "Plan:" "$RESULT_FILE" | tail -n 1)

      # Case 2: 변경 사항이 없는 경우
      NO_CHANGE_LINE=$(grep "No changes." "$RESULT_FILE" | head -n 1)

      if [ ! -z "$PLAN_LINE" ]; then
        RESULT_CONTENT="+ $PLAN_LINE"
        BLOCK_FMT="diff" # diff를 쓰면 + 기호가 초록색으로 뜸
      elif [ ! -z "$NO_CHANGE_LINE" ]; then
        RESULT_CONTENT="✅ No changes. Infrastructure is up-to-date."
        BLOCK_FMT="yaml"
      else
        RESULT_CONTENT="결과 요약을 찾을 수 없습니다. 상세 로그를 확인해주세요."
        BLOCK_FMT="text"
      fi

    elif [ "$NOTIFY_TYPE" == "apply" ]; then
      APPLY_LINE=$(grep "Apply complete!" "$RESULT_FILE" | tail -n 1)

      if [ ! -z "$APPLY_LINE" ]; then
         RESULT_CONTENT="$APPLY_LINE"
         BLOCK_FMT="css" # css를 쓰면 일반 텍스트도 깔끔하게 보임
      else
         RESULT_CONTENT="Apply 결과를 찾을 수 없습니다. 상세 로그를 확인해주세요."
         BLOCK_FMT="text"
      fi
    fi
  fi
fi

# 3. 상태별 색상 및 타이틀
if [ "$STATUS" == "success" ]; then
  COLOR=5763719 # Green
  EMOJI="✅"
else
  COLOR=15548997 # Red
  EMOJI="❌"
fi

if [ "$NOTIFY_TYPE" == "plan" ]; then
  TITLE="Terraform Plan Result"
  DESC="PR #$PR_NUMBER 변경 사항 감지"
elif [ "$NOTIFY_TYPE" == "apply" ]; then
  TITLE="Terraform Apply Result"
  DESC="Main 브랜치 배포 완료"
else
  TITLE="Terraform Action"
fi

# 4. JSON 생성 (jq 내부에서 포맷팅 조립)
# --arg fmt "$BLOCK_FMT" 를 추가하여 언어 설정
# value 부분에서 "```" + $fmt + "\n" + $content ... 로 조립
PAYLOAD=$(jq -n \
  --arg title "$EMOJI $TITLE" \
  --arg desc "$DESC" \
  --arg color "$COLOR" \
  --arg url "$Action_URL" \
  --arg actor "$ACTOR" \
  --arg branch "$BRANCH_INFO" \
  --arg content "$RESULT_CONTENT" \
  --arg fmt "$BLOCK_FMT" \
  '{
    username: "Terraform Bot",
    avatar_url: "