#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/fixture-explicit"
CATALOG="$ROOT/catalog-explicit"

rm -rf "$FIX" "$CATALOG"
mkdir -p "$FIX"

cat > "$FIX/terragrunt.stack.hcl" <<'STACK'
locals {
  catalog_path = "../catalog-explicit"
  cluster_name = "test-cluster"
  region       = "us-east-1"
}

unit "eks" {
  source = "${local.catalog_path}/units/eks-unified"
  path   = "eks"
  values = {
    cluster_name       = local.cluster_name
    kubernetes_version = "1.31"
    region             = local.region
  }
}

unit "eks-config" {
  source = "${local.catalog_path}/units/eks-config"
  path   = "eks-config"
  values = {
    cluster_name = local.cluster_name
    region       = local.region
  }
}

unit "karpenter" {
  source = "${local.catalog_path}/units/eks-karpenter"
  path   = "karpenter"
  values = {
    cluster_name = local.cluster_name
    region       = local.region
  }
}
STACK
mkdir -p "$CATALOG/units/eks-unified"
cat > "$CATALOG/units/eks-unified/terragrunt.hcl" <<'HCL'
terraform {
  source = "/workspace/catalog-explicit/modules/eks-unified"
}
HCL

mkdir -p "$CATALOG/units/eks-config"
cat > "$CATALOG/units/eks-config/terragrunt.hcl" <<'HCL'
terraform {
  source = "/workspace/catalog-explicit/modules/eks-config"
}
HCL

mkdir -p "$CATALOG/units/eks-karpenter"
cat > "$CATALOG/units/eks-karpenter/terragrunt.hcl" <<'HCL'
terraform {
  source = "/workspace/catalog-explicit/modules/eks-karpenter"
}
HCL

mkdir -p "$CATALOG/modules/eks-unified"
cat > "$CATALOG/modules/eks-unified/main.tf" <<'TF'
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

mkdir -p "$CATALOG/modules/eks-config"
cat > "$CATALOG/modules/eks-config/main.tf" <<'TF'
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

mkdir -p "$CATALOG/modules/eks-karpenter"
cat > "$CATALOG/modules/eks-karpenter/main.tf" <<'TF'
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

echo "✅ Explicit stack fixture created (3 units, 6 providers)"
