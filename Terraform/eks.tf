resource "aws_iam_role" "eks_cluster" {
  name = "roboshop-cluster-role-manoj"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  name     = "roboshop-eks"
  version  = "1.35"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1b.id
    ]
    endpoint_public_access = true
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_iam_role" "eks_nodes" {
  name = "roboshop-node-role-manoj"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---- Node Group in AZ-1a ----
resource "aws_eks_node_group" "az1a" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "roboshop-nodes-1a"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  instance_types  = ["m7i-flex.large"]
  subnet_ids      = [aws_subnet.private_1a.id]
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }
  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
  ]
  tags = {
    Name                                     = "roboshop-nodes-1a"
    "k8s.io/cluster-autoscaler/enabled"      = "true"
    "k8s.io/cluster-autoscaler/roboshop-eks" = "owned"
  }
}

# ---- Node Group in AZ-1b ----
resource "aws_eks_node_group" "az1b" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "roboshop-nodes-1b"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  instance_types  = ["m7i-flex.large"]
  subnet_ids      = [aws_subnet.private_1b.id]
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }
  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
  ]
  tags = {
    Name                                     = "roboshop-nodes-1b"
    "k8s.io/cluster-autoscaler/enabled"      = "true"
    "k8s.io/cluster-autoscaler/roboshop-eks" = "owned"
  }
}

# ---- OIDC Provider for IRSA ----
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  depends_on      = [aws_eks_cluster.main]
}
