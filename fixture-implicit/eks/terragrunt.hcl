terraform {
  source = "../modules/eks-unified"
}

inputs = {
  cluster_name       = "test-cluster"
  kubernetes_version = "1.31"
  region             = "us-east-1"
}
