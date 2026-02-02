# main.tf

module "iam" {
  source = "./modules/iam"
}

module "oidc" {
  source = "./modules/oidc"

  github_repo = "https://github.com/goorm-gongbang/301-goormgb-terraform.git"
}