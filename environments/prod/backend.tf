# environments/prod/backend.tf

terraform {
  backend "s3" {
    bucket         = "goorm-gongbang-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
