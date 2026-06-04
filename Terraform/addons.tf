# Metrics Server — required for HPA to read CPU/Memory
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  depends_on = [
    aws_eks_node_group.az1a,
    aws_eks_node_group.az1b
  ]
}

# Reloader — auto restarts pods when ConfigMap/Secret changes
resource "helm_release" "reloader" {
  name       = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  namespace  = "kube-system"

  depends_on = [
    aws_eks_node_group.az1a,
    aws_eks_node_group.az1b
  ]
}

# Cluster Autoscaler — auto scales EC2 nodes based on pending pods
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

  depends_on = [
    aws_eks_node_group.az1a,
    aws_eks_node_group.az1b
  ]
}
