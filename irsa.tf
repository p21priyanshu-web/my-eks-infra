###########################################################################
# IRSA - Cluster Autoscaler
###########################################################################

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:kube-system:cluster-autoscaler"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
###########################################################################
# IAM Role for Cluster Autoscaler
###########################################################################
resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.eks_cluster_name}-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume.json

  tags = var.tags
}
###########################################################################
# IAM Policy for Cluster Autoscaler
###########################################################################
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.eks_cluster_name}-autoscaler-policy"
  description = "IAM policy for EKS cluster autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
          }
        }
      }
    ]
  })

  tags = var.tags
}
###########################################################################
# Attach IAM Policy to IAM Role
###########################################################################
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}
###########################################################################
###########################################################################

# IRSA - AWS EBS CSI Driver
###########################################################################

# Trust relationship for AWS EBS CSI Driver using EKS OIDC
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test = "StringEquals"
      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:sub"

      values = [
        "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      ]
    }

    condition {
      test = "StringEquals"
      variable = "${replace(
        aws_iam_openid_connect_provider.eks.url,
        "https://",
        ""
      )}:aud"

      values = ["sts.amazonaws.com"]
    }
  }
}

###########################################################################
# IAM Role for AWS EBS CSI Driver
###########################################################################

resource "aws_iam_role" "ebs_csi" {
  name = "${var.eks_cluster_name}-ebs-csi-role"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json

  tags = var.tags
}

###########################################################################
# AWS Managed Policy for EBS CSI Driver
###########################################################################

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

  role = aws_iam_role.ebs_csi.name
}
###########################################################################
###########################################################################
# Trust relationship for AWS Load Balancer Controller using OIDC
###########################################################################

data "aws_iam_policy_document" "load_balancer_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.project_name}-${var.environment}-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume.json

  tags = var.tags
}

# IAM Policy for AWS Load Balancer Controller (using downloaded JSON)
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.project_name}-${var.environment}-aws-lbc-policy"
  description = "IAM policy for EKS AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = var.tags
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  policy_arn = aws_iam_policy.load_balancer_controller.arn
  role       = aws_iam_role.load_balancer_controller.name
}

###########################################################################
# IRSA - S3 Access
###########################################################################

data "aws_iam_policy_document" "s3_assume" {

  statement {

    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:prod:s3-pod"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}


###########################################################################
# IAM Role for S3 IRSA
###########################################################################

resource "aws_iam_role" "s3_irsa" {

  name = "${var.eks_cluster_name}-s3-irsa-role"

  assume_role_policy = data.aws_iam_policy_document.s3_assume.json

  tags = var.tags
}

###########################################################################
# IAM Policy for S3
###########################################################################

resource "aws_iam_policy" "s3_irsa" {

  name        = "${var.eks_cluster_name}-s3-policy"
  description = "Allow EKS Pod to access S3"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          "arn:aws:s3:::jiyna-my-production-bucket" 
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "arn:aws:s3:::jiyna-my-production-bucket/*"
        ]
      }

    ]
  })

  tags = var.tags
}

###########################################################################
# Attach Policy to Role
###########################################################################

resource "aws_iam_role_policy_attachment" "s3_irsa" {

  role       = aws_iam_role.s3_irsa.name
  policy_arn = aws_iam_policy.s3_irsa.arn

}
