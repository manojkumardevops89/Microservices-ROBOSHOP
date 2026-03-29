output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "eks_cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS Cluster Name"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS Cluster Endpoint"
}

output "nat_gateway_ip" {
  value       = aws_eip.nat.public_ip
  description = "NAT Gateway Public IP"
}

output "public_subnet_ids" {
  value       = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id
  ]
  description = "Public Subnet IDs"
}

output "private_subnet_ids" {
  value       = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id
  ]
  description = "Private Subnet IDs"
}
