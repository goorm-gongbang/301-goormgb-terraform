#!/bin/bash

# 필수 변수 확인
if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set."
  exit 1
fi

# 결과 파일 읽기 (없으면 빈 문자열)
RESULT_CONTENT=""
if [ -f "$RESULT_FILE" ]; then
  # 2000자 제한을 고려해 뒤에서 1500자만 자름
  RESULT_CONTENT=$(tail -c 1500 "$RESULT_FILE")
fi

# 상태에 따른 색상 및 타이틀 설정
if [ "$STATUS" == "success" ]; then
  COLOR=5763719 # Green
  EMOJI="✅"
else
  COLOR=15548997 # Red
  EMOJI="❌"
fi

# 메시지 내용 구성 (Plan vs Apply)
if [ "$NOTIFY_TYPE" == "plan" ]; then
  TITLE="Terraform Plan Result"
  DESC="PR #$PR_NUMBER 에서 Plan이 실행되었습니다."
  FIELD_NAME="Plan 요약"
elif [ "$NOTIFY_TYPE" == "apply" ]; then
  TITLE="Terraform Apply Result"
  DESC="Main 브랜치에 배포(Apply)가 실행되었습니다."
  FIELD_NAME="Apply 요약"
else
  echo "Error: Unknown NOTIFY_TYPE"
  exit 1
fi

# JSON 페이로드 생성 (jq 사용)
# 여기서 템플릿 구조를 관리합니다.
PAYLOAD=$(jq -n \
  --arg title "$EMOJI $TITLE" \
  --arg desc "$DESC" \
  --arg color "$COLOR" \
  --arg url "$Action_URL" \
  --arg actor "$ACTOR" \
  --arg branch "$BRANCH_INFO" \
  --arg field_name "$FIELD_NAME" \
  --arg content "$RESULT_CONTENT" \
  '{
    username: "Terraform Bot",
    avatar_url: "https://www.terraform.io/img/favicon.png",
    embeds: [{
      title: $title,
      description: $desc,
      url: $url,
      color: ($color | tonumber),
      fields: [
        {name: "수행자", value: $actor, inline: true},
        {name: "브랜치/PR", value: $branch, inline: true},
        {name: $field_name, value: ("```hcl\n" + $content + "\n```"), inline: false}
      ],
      footer: {text: "GitHub Actions • Terraform"}
    }]
  }'
)

# 디스코드로 전송
curl -H "Content-Type: application/json" \
     -d "$PAYLOAD" \
     "$DISCORD_WEBHOOK"