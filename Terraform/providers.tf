provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

#In my Terraform code I have configured three providers — AWS, Kubernetes and Helm.
#First is the AWS provider where I specify the region using a variable. This tells Terraform to create and manage all resources in that particular AWS region.
#Second is the Kubernetes provider. Here I provide three things — the EKS cluster endpoint as host, the cluster CA certificate for SSL verification and the authentication token. These three things together allow Terraform to connect to my EKS cluster and manage Kubernetes resources like deployments and services.
#Third is the Helm provider. Helm runs on top of Kubernetes so it needs the same EKS cluster credentials — same host, same certificate and same token. This allows Terraform to deploy my RoboShop Helm charts directly into the EKS cluster.
#I also have a data block called aws_eks_cluster_auth which fetches the authentication token of the EKS cluster. This token is then used by both Kubernetes and Helm providers to authenticate into the cluster
