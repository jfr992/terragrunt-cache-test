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
