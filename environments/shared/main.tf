provider "aws" {
  region = "ap-northeast-2"
}

module "backend" {
  source = "../../modules/backend"

  bucket_name         = "goormgb-terraform-state-bucket"
  dynamodb_table_name = "goormgb-terraform-lock-table"
}

module "route53" {
  source = "../../modules/route53_zone"

  domain_name = "goormgb.space"
}
