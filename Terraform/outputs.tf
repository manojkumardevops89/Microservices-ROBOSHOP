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
#outputs.tf serves three purposes. First, it displays important resource information on terminal after terraform apply so I don't have to manually search in AWS console. Second, I can directly use these values for next steps like connecting kubectl using cluster name or whitelisting NAT IP in database firewall. Third, when using Terraform modules, outputs allow one module to pass values to another module — like VPC module passing subnet IDs to EKS module."
