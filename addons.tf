###########################################################################
# EKS Managed Add-on - AWS EBS CSI Driver
###########################################################################

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    var.tags,
    {
      Name = "${var.eks_cluster_name}-ebs-csi"
    }
  )

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

###########################################################################
# Cluster Autoscaler
###########################################################################

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"

  # Pin chart version for predictable production deployments
  version = "9.37.0"

  # Automatically discover the ASG created by the EKS Managed Node Group
  set = [
  {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  },
  {
    name  = "awsRegion"
    value = var.aws_region
  },
  {
    name  = "rbac.serviceAccount.create"
    value = "true"
  },
  {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  },
  {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  },
  {
    name  = "replicaCount"
    value = "1"
  }
]

  # Wait until the EKS worker nodes and IRSA permissions exist
  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.cluster_autoscaler
  ]
}