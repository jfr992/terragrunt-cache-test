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
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
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

variable "cluster_name" {
  type    = string
  default = "test-cluster"
}
variable "kubernetes_version" {
  type    = string
  default = "1.31"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

resource "null_resource" "eks" {
  triggers = { cluster = var.cluster_name }
}

output "cluster_name" { value = var.cluster_name }
