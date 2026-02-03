#!/bin/bash

# 1. 필수 변수 체크
if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set."
  exit 1
fi

# 2. 결과 파일 읽기 및 포맷팅 설정
if [ ! -f "$RESULT_FILE" ]; then
  RESULT_CONTENT="결과 파일을 찾을 수 없습니다."
  BLOCK_FMT="text"
else
  # ------------------------------------------------------------------
  # 로그 파싱 로직
  # ------------------------------------------------------------------

  if [ "$STATUS" != "success" ]; then
    # 실패 시 Error 라인 추출
    EXTRACTED=$(grep "Error:" "$RESULT_FILE" | head -n 1)
    if [ -z "$EXTRACTED" ]; then
      EXTRACTED=$(tail -n 3 "$RESULT_FILE")
    fi
    RESULT_CONTENT="🚫 오류 발생: $EXTRACTED"
    BLOCK_FMT="text"

  else
    # 성공 시 Plan/Apply 구분
    if [ "$NOTIFY_TYPE" == "plan" ]; then
      PLAN_LINE=$(grep "Plan:" "$RESULT_FILE" | tail -n 1)
      NO_CHANGE_LINE=$(grep "No changes." "$RESULT_FILE" | head -n 1)

      if [ ! -z "$PLAN_LINE" ]; then
        RESULT_CONTENT="+ $PLAN_LINE"
        BLOCK_FMT="diff"
      elif [ ! -z "$NO_CHANGE_LINE" ]; then
        RESULT_CONTENT="✅ 변경 사항이 없습니다. 모든 인프라가 최신상태 입니다."
        BLOCK_FMT="yaml"
      else
        RESULT_CONTENT="결과 요약을 찾을 수 없습니다. 상세 로그를 확인해주세요."
        BLOCK_FMT="text"
      fi

    elif [ "$NOTIFY_TYPE" == "apply" ]; then
      # Apply 완료 메시지 찾기
      APPLY_LINE=$(grep "적용 성공!" "$RESULT_FILE" | tail -n 1)

      if [ ! -z "$APPLY_LINE" ]; then
         RESULT_CONTENT="$APPLY_LINE"
         BLOCK_FMT="css"
      else
         RESULT_CONTENT="Apply 결과를 찾을 수 없습니다. 상세 로그를 확인해주세요."
         BLOCK_FMT="text"
      fi
    fi
  fi
fi

# 3. UI/UX 설정
if [ "$STATUS" == "success" ]; then
  COLOR=5763719 # Green
  EMOJI="✅"
else
  COLOR=15548997 # Red
  EMOJI="❌"
fi

# 수행자 프로필 이미지 (GitHub 기본 프로필 URL 활용)
USER_ICON="https://github.com/${ACTOR}.png"

# 알림 타입별 필드 설정
if [ "$NOTIFY_TYPE" == "plan" ]; then
  TITLE="Terraform Plan Result"
  DESC="PR 변경 사항 감지"

  # Plan 단계에서는 브랜치 정보 표시
  INFO_NAME="브랜치"
  INFO_VALUE="$BRANCH_INFO"

elif [ "$NOTIFY_TYPE" == "apply" ]; then
  TITLE="Terraform Apply Result"
  DESC="Main 브랜치 배포 완료"

  # Apply 단계에서는 '어떤 PR이 머지되었는지' 커밋 메시지로 표시
  INFO_NAME="머지 정보 (Commit)"
  # 커밋 메시지가 너무 길면 첫 줄만 자르기
  INFO_VALUE=$(echo "$COMMIT_MSG" | head -n 1)

else
  TITLE="Terraform Action"
  DESC="알 수 없는 액션"
  INFO_NAME="Info"
  INFO_VALUE="N/A"
fi

# 4. JSON 생성
# author 필드를 사용하여 수행자 이름과 프로필 아이콘을 상단에 배치
PAYLOAD=$(jq -n \
  --arg title "$EMOJI $TITLE" \
  --arg desc "$DESC" \
  --arg color "$COLOR" \
  --arg url "$Action_URL" \
  --arg actor "$ACTOR" \
  --arg user_icon "$USER_ICON" \
  --arg info_name "$INFO_NAME" \
  --arg info_value "$INFO_VALUE" \
  --arg content "$RESULT_CONTENT" \
  --arg fmt "$BLOCK_FMT" \
  '{
    embeds: [{
      author: {
        name: $actor,
        icon_url: $user_icon
      },
      title: $title,
      description: ($desc + "\n[👉 상세 로그 보러가기](" + $url + ")"),
      url: (if $url == "" or $url == null then null else $url end),
      color: ($color | tonumber),
      fields: [
        {name: $info_name, value: $info_value, inline: true},
        {
          name: "결과 요약",
          value: ("```" + $fmt + "\n" + $content + "\n```"),
          inline: false
        }
      ],
      footer: {text: "GitHub Actions • Terraform"}
    }]
  }'
)

curl -H "Content-Type: application/json" \
     -d "$PAYLOAD" \
     "$DISCORD_WEBHOOK"