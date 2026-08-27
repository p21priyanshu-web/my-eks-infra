###########################################################################
# Reading the available availability zones in the region
###########################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

###########################################################################
# VPC Definition
###########################################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.eks_cluster_name}-vpc"
  }
}
###########################################################################
# Public Subnets Definition  
###########################################################################
resource "aws_subnet" "jiyna_eks_public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.eks_cluster_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}
###########################################################################
# Private Subnets Definition  
###########################################################################
resource "aws_subnet" "jiyna_eks_private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.eks_cluster_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
###########################################################################
# Internet Gateway Definition For Public Subnets
###########################################################################
resource "aws_internet_gateway" "jiyna_eks_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.eks_cluster_name}-igw"
  }
}
###########################################################################
# Creating Elastic IP for NAT Gateway For private Subnets
###########################################################################
resource "aws_eip" "jiyna_eks_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.eks_cluster_name}-nat-eip"
  }
}
###########################################################################
# NAT Gateway Definition For Private Subnets Outbound Internet Access
###########################################################################
resource "aws_nat_gateway" "jiyna_eks_nat_gw" {
  allocation_id = aws_eip.jiyna_eks_nat_eip.id
  subnet_id     = aws_subnet.jiyna_eks_public_subnet[0].id

  tags = {
    Name = "${var.eks_cluster_name}-nat-gw"
  }
  depends_on = [aws_internet_gateway.jiyna_eks_igw]
}
###########################################################################
# Route Table for Public Subnets
###########################################################################
resource "aws_route_table" "jiyna_eks_public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jiyna_eks_igw.id
  }
  tags = {
    Name = "${var.eks_cluster_name}-public-rt"
  }
}
###########################################################################
# Route Table for Private Subnets
###########################################################################
resource "aws_route_table" "jiyna_eks_private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.jiyna_eks_nat_gw.id
  }
  tags = {
    Name = "${var.eks_cluster_name}-private-rt"
  }
}
###########################################################################
# Associating Public Subnets with Public Route Table
###########################################################################
resource "aws_route_table_association" "jiyna_eks_public_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.jiyna_eks_public_subnet[count.index].id
  route_table_id = aws_route_table.jiyna_eks_public_rt.id
}
###########################################################################
# Associating Private Subnets with Private Route Table
###########################################################################
resource "aws_route_table_association" "jiyna_eks_private_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.jiyna_eks_private_subnet[count.index].id
  route_table_id = aws_route_table.jiyna_eks_private_rt.id
}
