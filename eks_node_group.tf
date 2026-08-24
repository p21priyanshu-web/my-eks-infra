###########################################################################
# Security Group for Kubernetes Worker Nodes
###########################################################################
resource "aws_security_group" "nodes" {
  name        = "${var.project_name}-${var.environment}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Ingress: allow all traffic between nodes in the group (kubelet, pods, network plugins)
  ingress {
    description = "Allow intra-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Ingress: allow control plane API server to contact nodes (kubelet ports, webhooks, exec/logs)
  ingress {
    description     = "Allow EKS control plane traffic to nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # Ingress: allow control plane HTTPS traffic (needed for certain webhooks and admission controllers)
  ingress {
    description     = "Allow EKS control plane HTTPS traffic to nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # Egress: allow nodes to communicate with external endpoints (image pulls, AWS APIs, external databases)
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
      Name                                                                          = "${var.project_name}-${var.environment}-node-sg"
      "kubernetes.io/cluster/${var.project_name}-${var.environment}-cluster"        = "owned"
    }
  )
}
###########################################################################
# Allow Worker Nodes to make EKS API calls (ingress rule on control plane SG)
###########################################################################
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow worker nodes/pods to call EKS Control Plane API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
}
###########################################################################
# Custom Launch Template for EKS Worker Nodes
###########################################################################
resource "aws_launch_template" "nodes" {
  name_prefix   = "${var.eks_cluster_name}-node-lt-"
  description   = "Launch template for EKS Managed Node Group"

  # We omit image_id to allow EKS Managed Node Group to use its standard, up-to-date EKS-Optimized AMI

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_volume_size
      volume_type           = var.node_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2 (prevents credentials theft)
    http_put_response_hop_limit = 2          # Allow containers/pods to access metadata if authorized
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = true # Enable detailed monitoring for production nodes
  }

  vpc_security_group_ids = [aws_security_group.nodes.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-worker-node"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}
###########################################################################
# EKS Managed Node Group (deployed in Private Subnets only)
###########################################################################
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  instance_types = var.node_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  # Node upgrade rollout configuration
  update_config {
    max_unavailable = 1
  }

  # EKS managed node groups are automatically updated when EKS rolls out a new AMI version.
  # We ignore changes to desired_size so that Cluster Autoscaler can scale nodes without Terraform resetting them.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Cluster Autoscaler Tags
  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/enabled"                                           = "true"
      "k8s.io/cluster-autoscaler/${var.project_name}-${var.environment}-cluster"    = "owned"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_registry,
    aws_iam_role_policy_attachment.node_ssm
  ]
}
