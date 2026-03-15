terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "tf-state-gcc-457591021188"
    key            = "gcc/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
