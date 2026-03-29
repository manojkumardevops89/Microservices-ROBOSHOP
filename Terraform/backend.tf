terraform {
  backend "s3" {
    bucket = "roboshop-terraform-state"
    key    = "roboshop/terraform.tfstate"
    region = "us-east-1"
  }
}
