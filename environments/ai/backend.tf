# environments/ai/backend.tf

terraform {
  backend "s3" {
    bucket         = "goorm-gongbang-tf-state"
    key            = "ai/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
