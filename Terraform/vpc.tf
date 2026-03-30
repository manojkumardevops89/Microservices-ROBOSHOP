resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "roboshop-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "roboshop-igw" }
}

# ---- Public Subnet AZ-1a ----
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "roboshop-public-1a"
    "kubernetes.io/role/elb"             = "1"
    "kubernetes.io/cluster/roboshop-eks" = "shared"
  }
}

# ---- Public Subnet AZ-1b ----
resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "roboshop-public-1b"
    "kubernetes.io/role/elb"             = "1"
    "kubernetes.io/cluster/roboshop-eks" = "shared"
  }
}

# ---- Private Subnet AZ-1a (worker nodes) ----
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "roboshop-private-1a"
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/roboshop-eks" = "shared"
  }
}

# ---- Private Subnet AZ-1b (worker nodes) ----
resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "roboshop-private-1b"
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/roboshop-eks" = "shared"
  }
}

# ---- NAT Gateway (so private subnets can reach internet) ----
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id
  tags          = { Name = "roboshop-nat" }
}

# ---- Route Tables ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "roboshop-public-rt" }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "roboshop-private-rt" }
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private.id
}
#In my vpc.tf file, I am setting up the complete network infrastructure on AWS for our Roboshop EKS project using Terraform.
First, I created a VPC with CIDR block 10.0.0.0/16 which is the main private network where all our resources live.
Inside that VPC, I created 4 subnets — 2 public and 2 private — one of each in two different Availability Zones. This gives us High Availability, so if one zone goes down, the other is still running.
Public subnets are for Load Balancers — they face the internet. Private subnets are for EKS worker nodes — they are not directly accessible from internet for security reasons.
For internet connectivity, I attached an Internet Gateway to the VPC. Public subnets route their traffic directly through the IGW.
For private subnets, I created a NAT Gateway placed in the public subnet. This allows worker nodes to reach the internet outbound — for example to pull container images or download packages — but blocks any inbound traffic from internet to nodes.
Finally I created two route tables — one for public subnets pointing to IGW, one for private subnets pointing to NAT Gateway — and associated them with the correct subnets.
I also added Kubernetes specific tags on subnets so that EKS knows which subnets to use when creating Load Balancers automatically."
