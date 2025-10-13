locals {
  catalog_path = "../catalog-explicit"
  cluster_name = "test-cluster"
  region       = "us-east-1"
}

# Group 1: EKS Cluster Foundation
unit "eks" {
  source = "${local.catalog_path}/units/eks-unified"
  path   = "eks"
  values = {
    cluster_name       = local.cluster_name
    kubernetes_version = "1.31"
    region             = local.region
  }
}

# Group 2: EKS Custom Networking and Addons
unit "eks-config" {
  source = "${local.catalog_path}/units/eks-config"
  path   = "eks-config"
  values = {
    cluster_name = local.cluster_name
    region       = local.region
  }
}

# Group 3: Karpenter Autoscaling
unit "karpenter" {
  source = "${local.catalog_path}/units/eks-karpenter"
  path   = "karpenter"
  values = {
    cluster_name = local.cluster_name
    region       = local.region
  }
}
