terraform {
  backend "s3" {
    bucket         = "goormgb-tf-state-bucket"
    key            = "shared/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "route53" {
  source = "../../modules/route53_zone"

  domain_name = "goormgb.space"
}