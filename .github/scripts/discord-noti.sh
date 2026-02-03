#!/bin/bash

# 1. 필수 변수 체크
if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set."
  exit 1
fi

# 2. 결과 파일 읽기 (없으면 '내용 없음' 처리)
RESULT_CONTENT="내용 없음"
if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
  # 2000자 제한 고려 (넉넉하게 1500자)
  RESULT_CONTENT=$(tail -c 1500 "$RESULT_FILE")
fi

# 3. 상태별 색상/이모지 설정
if [ "$STATUS" == "success" ]; then
  COLOR=5763719 # Green
  EMOJI="✅"
else
  COLOR=15548997 # Red
  EMOJI="❌"
fi

# 4. 알림 타입별 텍스트 설정
if [ "$NOTIFY_TYPE" == "plan" ]; then
  TITLE="Terraform Plan Result"
  DESC="PR #$PR_NUMBER 에서 Plan이 실행되었습니다."
  FIELD_NAME="Plan 요약"
elif [ "$NOTIFY_TYPE" == "apply" ]; then
  TITLE="Terraform Apply Result"
  DESC="Main 브랜치에 배포(Apply)가 실행되었습니다."
  FIELD_NAME="Apply 요약"
else
  # 기본값 처리 (에러 방지)
  TITLE="Terraform Action"
  DESC="알 수 없는 액션이 실행되었습니다."
  FIELD_NAME="Output"
fi

# 5. JSON 생성 (jq 활용)
# 중요: URL이 비어있으면 null로 처리해야 에러가 안 남
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
      url: (if $url == "" or $url == null then null else $url end),
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

# 6. 디버깅: 전송될 페이로드 출력 (로그에서 확인 가능하도록)
echo "---------------- PAYLOAD ----------------"
echo "$PAYLOAD"
echo "-----------------------------------------"

# 7. 디스코드 전송
curl -H "Content-Type: application/json" \
     -d "$PAYLOAD" \
     "$DISCORD_WEBHOOK"