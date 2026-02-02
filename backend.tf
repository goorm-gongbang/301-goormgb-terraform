# backend.tf
terraform {
  backend "s3" {
    bucket = "goorm-gongbang-tf-state"
    key = "terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}