# AWS Load Balancer Controller — creates ALB when Ingress is applied
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [
    aws_eks_node_group.az1a,
    aws_eks_node_group.az1b
  ]
}
