# main.tf
module "iam" {
  source = "./modules/iam"
}

module "oidc" {
  source = "./modules/oidc"

  github_repo = "goorm-gongbang/301-goormgb-terraform"
}