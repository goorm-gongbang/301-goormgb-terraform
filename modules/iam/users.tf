# iam/users.tf
locals {
  users_map = {
    # -----------------------------------------------
    # 1. Product Group (PM & PD -> projectmanage)
    # -----------------------------------------------
    "PM-jehyun"  = ["projectmanage"]
    "PM-hs"      = ["projectmanage"]
    "PD-seyoun9" = ["projectmanage"]
    "PD-jbyun"   = ["projectmanage"]

    # -----------------------------------------------
    # 2. Backend Group (BE -> backend)
    # -----------------------------------------------
    "BE-seulgi" = ["backend"]
    "BE-ejinn"  = ["backend"]

    # -----------------------------------------------
    # 3. Frontend Group (FE -> frontend)
    # -----------------------------------------------
    "FE-hyogi" = ["frontend"]

    # -----------------------------------------------
    # 4. Fullstack Group (FS -> backend + frontend)
    # -----------------------------------------------
    "FS-siyeon" = ["backend", "frontend"]

    # -----------------------------------------------
    # 5. AI Group (AI -> AI)
    # -----------------------------------------------
    "AI-jihyeoniu" = ["AI"]
    "AI-donghoon"  = ["AI"]

    # -----------------------------------------------
    # 6. Security Group (CS -> security)
    # -----------------------------------------------
    "CS-minwook" = ["security"]
    "CS-wanwoo"  = ["security"]
    "CS-jiseo"   = ["security"]
  }
}

# 1. IAM 사용자 생성
resource "aws_iam_user" "this" {
  for_each = local.users_map

  name          = each.key
  path          = "/users/"
  force_destroy = true
}

# 2. IAM 사용자 그룹 멤버십 설정
# 리스트형태의 그룹 정보를 받아서 처리
resource "aws_iam_user_group_membership" "this" {
  for_each = local.users_map

  user = aws_iam_user.this[each.key].name

  groups = [
    # groups.tf에 있는 aws_iam_group 리소스를 참조하여 이름 가져오기
    for group_key in each.value : aws_iam_group.this[group_key].name
  ]
}