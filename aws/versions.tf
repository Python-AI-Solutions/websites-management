terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  backend "gcs" {
    bucket = "k8s-tfstate-midyear-pattern-470017-b8"
    prefix = "aws-infra/terraform.tfstate"
  }
}
