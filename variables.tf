variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "eks_cluster_name" {
  type    = string
  default = "jiyna-eks-cluster"
}

variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "project_name" {
  type    = string
  default = "jiyna-eks-project"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "tags" {
  type = map(string)
  default = {
    "Project"     = "jiyna-eks-project"
    "Environment" = "dev"
  }
}
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}
variable "eks_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}
variable "eks_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint. WARNING: Restrict this in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
variable "eks_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}
variable "node_volume_size" {
  description = "Size of the root EBS volume for each worker node (in GiB)"
  type        = number
  default     = 15
}
variable "node_volume_type" {
  description = "EBS volume type for worker node root disks"
  type        = string
  default     = "gp3"
}
variable "node_min_size" {
  description = "Minimum number of worker nodes for the Managed Node Group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for the Managed Node Group"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes for the Managed Node Group"
  type        = number
  default     = 2
}
variable "node_instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["t2.medium"]
}
