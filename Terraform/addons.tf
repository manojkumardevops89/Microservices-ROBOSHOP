# IAM Policy for Cluster Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  name = "roboshop-cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ]
      Resource = "*"
    }]
  })
}

# Attach policy to node role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  depends_on = [aws_eks_node_group.az1a, aws_eks_node_group.az1b]
}

# Reloader
resource "helm_release" "reloader" {
  name       = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  namespace  = "kube-system"
  depends_on = [aws_eks_node_group.az1a, aws_eks_node_group.az1b]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  }
  set {
    name  = "awsRegion"
    value = var.region
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eks_nodes.arn
  }

  depends_on = [
    aws_eks_node_group.az1a,
    aws_eks_node_group.az1b,
    aws_iam_role_policy_attachment.cluster_autoscaler
  ]
}
