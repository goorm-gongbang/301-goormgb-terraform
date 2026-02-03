#!/bin/bash

# 1. 필수 변수 체크
if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set."
  exit 1
fi

# 2. 결과 파일이 없으면 처리
if [ ! -f "$RESULT_FILE" ]; then
  echo "Error: Result file not found."
  RESULT_CONTENT="결과 파일을 찾을 수 없습니다."
else
  # ------------------------------------------------------------------
  # 핵심 로직: 로그에서 '요약 한 줄'만 추출하기 (grep 활용)
  # ------------------------------------------------------------------

  # A. 실패(Failure)한 경우: "Error:" 로 시작하는 줄을 찾음
  if [ "$STATUS" != "success" ]; then
    # Error로 시작하는 줄을 찾거나, 없으면 마지막 5줄 가져오기
    EXTRACTED=$(grep "Error:" "$RESULT_FILE" | head -n 1)
    if [ -z "$EXTRACTED" ]; then
      EXTRACTED=$(tail -n 3 "$RESULT_FILE")
    fi
    RESULT_CONTENT="🚫 **오류 발생**\n\`\`\`text\n$EXTRACTED\n...\`\`\`"

  # B. 성공(Success)한 경우: Plan 또는 Apply 결과 요약 찾기
  else
    if [ "$NOTIFY_TYPE" == "plan" ]; then
      # Case 1: 변경 사항이 있는 경우 ("Plan: X to add ...")
      PLAN_LINE=$(grep "Plan:" "$RESULT_FILE" | tail -n 1)

      # Case 2: 변경 사항이 없는 경우 ("No changes.")
      NO_CHANGE_LINE=$(grep "No changes." "$RESULT_FILE" | head -n 1)

      if [ ! -z "$PLAN_LINE" ]; then
        RESULT_CONTENT="\`\`\`diff\n+ $PLAN_LINE\n\`\`\`"
      elif [ ! -z "$NO_CHANGE_LINE" ]; then
        RESULT_CONTENT="\`\`\`yaml\n✅ No changes. Infrastructure is up-to-date.\n\`\`\`"
      else
        # 요약 문구를 못 찾은 경우 (드물지만 발생 가능)
        RESULT_CONTENT="결과 요약을 찾을 수 없습니다. 상세 로그를 확인해주세요."
      fi

    elif [ "$NOTIFY_TYPE" == "apply" ]; then
      # Case 1: Apply 완료 ("Apply complete! Resources: ...")
      APPLY_LINE=$(grep "Apply complete!" "$RESULT_FILE" | tail -n 1)

      if [ ! -z "$APPLY_LINE" ]; then
         RESULT_CONTENT="\`\`\`css\n$APPLY_LINE\n\`\`\`"
      else
         RESULT_CONTENT="Apply 결과를 찾을 수 없습니다. 상세 로그를 확인해주세요."
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

# 4. JSON 생성 (Field Value를 핵심 요약으로 대체)
# Description에 '자세히 보기' 문구를 추가하여 클릭 유도
PAYLOAD=$(jq -n \
  --arg title "$EMOJI $TITLE" \
  --arg desc "$DESC" \
  --arg color "$COLOR" \
  --arg url "$Action_URL" \
  --arg actor "$ACTOR" \
  --arg branch "$BRANCH_INFO" \
  --arg content "$RESULT_CONTENT" \
  '{
    username: "Terraform Bot",
    avatar_url: "https://www.terraform.io/img/favicon.png",
    embeds: [{
      title: $title,
      description: ($desc + "\n[👉 상세 로그 보러가기](" + $url + ")"),
      url: (if $url == "" or $url == null then null else $url end),
      color: ($color | tonumber),
      fields: [
        {name: "수행자", value: $actor, inline: true},
        {name: "브랜치", value: $branch, inline: true},
        {name: "결과 요약", value: $content, inline: false}
      ],
      footer: {text: "GitHub Actions • Terraform"}
    }]
  }'
)

echo "---------------- PAYLOAD ----------------"
echo "$PAYLOAD"
echo "-----------------------------------------"

curl -H "Content-Type: application/json" \
     -d "$PAYLOAD" \
     "$DISCORD_WEBHOOK"