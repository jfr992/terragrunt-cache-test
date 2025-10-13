terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "kubernetes" {
  config_path = "/dev/null"
}

provider "kubectl" {
  config_path = "/dev/null"
}

variable "cluster_name" {
  type    = string
  default = "test-cluster"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

resource "null_resource" "eks_config" {
  triggers = { cluster = var.cluster_name }
}

output "status" { value = "configured" }
