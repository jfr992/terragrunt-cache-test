#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/fixture-implicit"

rm -rf "$FIX"
mkdir -p "$FIX"

mkdir -p "$FIX/eks"
cat > "$FIX/eks/terragrunt.hcl" <<'HCL'
terraform {
  source = "../modules/eks-unified"
}

inputs = {
  cluster_name       = "test-cluster"
  kubernetes_version = "1.31"
  region             = "us-east-1"
}
HCL

mkdir -p "$FIX/eks-config"
cat > "$FIX/eks-config/terragrunt.hcl" <<'HCL'
terraform {
  source = "../modules/eks-config"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["plan"]
}

inputs = {
  cluster_name = "test-cluster"
  region       = "us-east-1"
}
HCL

mkdir -p "$FIX/karpenter"
cat > "$FIX/karpenter/terragrunt.hcl" <<'HCL'
terraform {
  source = "../modules/eks-karpenter"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["plan"]
}

inputs = {
  cluster_name = "test-cluster"
  region       = "us-east-1"
}
HCL

mkdir -p "$FIX/modules/eks-unified"
cat > "$FIX/modules/eks-unified/main.tf" <<'TF'
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
TF

mkdir -p "$FIX/modules/eks-config"
cat > "$FIX/modules/eks-config/main.tf" <<'TF'
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
TF

mkdir -p "$FIX/modules/eks-karpenter"
cat > "$FIX/modules/eks-karpenter/main.tf" <<'TF'
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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
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

provider "helm" {
  kubernetes {
    config_path = "/dev/null"
  }
}

variable "cluster_name" {
  type    = string
  default = "test-cluster"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

resource "null_resource" "karpenter" {
  triggers = { cluster = var.cluster_name }
}

output "status" { value = "karpenter-installed" }
TF

echo "✅ Implicit stack fixture created (3 units, 6 providers)"
