resource "aws_iam_role" "eks_cluster" { #resource-Terraform keyword,aws_iam_role-Resource type — creating an IAM Role in AWS,eks_cluster-Local name — used inside Terraform to reference this resource.
  name = "roboshop-cluster-role-manoj" #Actual name created in AWS console/account

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
#Above This creates an IAM role and attaches a trust policy that allows the EKS service to assume it — which is required for EKS to manage AWS resources like EC2, VPC, and autoscaling on your behalf

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {# Attach permission policy to EKS cluster role
  role       = aws_iam_role.eks_cluster.name #Which role to give permissions to? ,refers to cluster IAM role created earlier

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" #What permissions to give?, AWS managed policy that allows EKS to manage-EC2 nodes,Networking,Load Balancers,Security Groups,Cloudwatch logs
}

resource "aws_eks_cluster" "main" {
  name     = "roboshop-eks"
  version  = "1.29"
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
  instance_types  = ["t3.medium"]
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

  tags = { Name = "roboshop-nodes-1a" }
}

# ---- Node Group in AZ-1b ----
resource "aws_eks_node_group" "az1b" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "roboshop-nodes-1b"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  instance_types  = ["t3.medium"]
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

  tags = { Name = "roboshop-nodes-1b" }
}


# 2nd block This block is attaching the AmazonEKSClusterPolicy to the EKS cluster IAM role.
When I create an IAM role it is just an empty container with no permissions. So I need to attach a policy to give it actual permissions.
AmazonEKSClusterPolicy is an AWS managed policy which gives EKS cluster permissions to manage EC2 nodes, networking, security groups, load balancers and CloudWatch logs.
Without this policy attachment EKS cluster is created but cannot manage anything in AWS — so this is mandatory for EKS cluster to function properly.
#3rd block This block actually creates the EKS cluster in AWS. I give it a name roboshop-eks and Kubernetes version 1.29. I attach the IAM role using role_arn so the cluster has permissions to manage AWS resources.
In vpc_config I place the cluster in two private subnets across two availability zones for high availability and security. I also set endpoint_public_access to true so I can manage the cluster using kubectl from my local machine.
I use depends_on to make sure the IAM policy is fully attached before the cluster is created — otherwise cluster would start without proper permissions and fail

#"In my eks.tf file, I am setting up a complete EKS Kubernetes cluster on AWS using Terraform.
First, I created two IAM roles — one for the EKS cluster and one for the worker nodes. The cluster role allows the EKS service to manage AWS resources like load balancers and networking on our behalf. The node role allows EC2 instances to join the cluster, pull container images from ECR, and manage pod networking using the CNI plugin.
Then I created the actual EKS cluster called roboshop-eks running Kubernetes version 1.29, placed in private subnets for security, with public endpoint access enabled so we can run kubectl commands from our local machine.
Finally, I created two node groups — one in each availability zone — using t3.medium instances. This gives us High Availability, so if one AZ goes down, the other is still running. Each node group can scale from 1 to 2 nodes based on load."
