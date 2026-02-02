# main.tf
# 테스트용 주석입니다.
module "iam" {
  source = "./modules/iam"
}

module "oidc" {
  source = "./modules/oidc"

  github_repo = "https://github.com/goorm-gongbang/301-goormgb-terraform.git"
}