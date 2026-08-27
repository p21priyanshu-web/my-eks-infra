###########################################################################
# EKS Cluster Control Plane Security Group
###########################################################################
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security group for EKS control plane API server"
  vpc_id      = aws_vpc.main.id

  # Egress: allow EKS control plane to communicate with anything (e.g. nodes, external APIs)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
    }
  )
}
###########################################################################
# EKS Control Plane
###########################################################################
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.jiyna_eks_public_subnet[*].id, aws_subnet.jiyna_eks_private_subnet[*].id)
    endpoint_private_access = var.eks_endpoint_private_access
    endpoint_public_access  = var.eks_endpoint_public_access
    public_access_cidrs     = var.eks_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # --- MODIFICATION: EKS Access Configuration (API and ConfigMap both) ---
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  #   # Enable envelope encryption for Kubernetes Secrets using KMS CMK
  #   encryption_config {
  #     provider {
  #       key_arn = aws_kms_key.eks.arn
  #     }
  #     resources = ["secrets"]
  #   }

  # Enable control plane logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks,
    aws_iam_role_policy_attachment.cluster_vpc,
    aws_cloudwatch_log_group.eks
  ]

  tags = var.tags
}

###########################################################################
# --- MODIFICATION: ADDED FOR TERRAFORM VALIDATE FIX ---
# EKS CloudWatch Log Group for Control Plane Logging
###########################################################################
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags
}

