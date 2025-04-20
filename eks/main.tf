provider "aws" {
  region = local.region
}

data "aws_ami" "eks_default_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-arm64-node-${local.cluster_version}-v*"]
  }
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

variable "vpc_cidr" {}
variable "name" {}
variable "region" {}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_id" {}
variable "instance_types_service_arm_64" {
  type = list(string)
}
variable "instance_types_service" {
  type = list(string)
}
variable "subnet_ids_private" {
  type = list(string)
}


locals {
  name            = var.name
  cluster_version = "1.29"
  region          = var.region

  vpc_cidr = var.vpc_cidr


  tags = {
    "kubernetes.io/cluster/${var.name}"          = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
    "eks/cluster/${var.name}/node_group/default" = "true"
  }
}



module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  # IPV6
  cluster_ip_family = "ipv4"

  enable_cluster_creator_admin_permissions = true

  # Enable EFA support by adding necessary security group rules
  # to the shared node security group
  enable_efa_support = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.11.1-eksbuild.8"
      resolve_conflicts="PRESERVE"
    }
    kube-proxy = {
      addon_version = "v1.29.3-eksbuild.2"
      resolve_conflicts="PRESERVE"
    }
    vpc-cni = {
      addon_version = "v1.18.1-eksbuild.1"
      resolve_conflicts="PRESERVE"
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.30.0-eksbuild.1"
      resolve_conflicts="PRESERVE"
    }        
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    # Use a custom AMI
    # services_arm_64 = {
    #   ami_type = "AL2_x86_64"
    #   # Current default AMI used by managed node groups - pseudo "custom"
    #   ami_id       = data.aws_ami.eks_default_arm.image_id
    #   min_size     = 1
    #   max_size     = 4
    #   desired_size = 1
    #   # This will ensure the bootstrap user data is used to join the node
    #   # By default, EKS managed node groups will not append bootstrap script;
    #   # this adds it back in using the default template provided by the module
    #   # Note: this assumes the AMI provided is an EKS optimized AMI derivative
    #   enable_bootstrap_user_data = true
    #   subnet_ids                 = var.subnet_ids_private
    #   instance_types             = var.instance_types_service_arm_64
    # }
    services = {
      ami_type = "AL2_x86_64"
      # Current default AMI used by managed node groups - pseudo "custom"
      ami_id       = data.aws_ami.eks_default.image_id
      min_size     = 2
      max_size     = 4
      desired_size = 2
      # This will ensure the bootstrap user data is used to join the node
      # By default, EKS managed node groups will not append bootstrap script;
      # this adds it back in using the default template provided by the module
      # Note: this assumes the AMI provided is an EKS optimized AMI derivative
      enable_bootstrap_user_data = true
      subnet_ids                 = var.subnet_ids_private
      instance_types             = var.instance_types_service
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }  
      bootstrap_extra_args = <<-EOT
        --use-max-pods false
      EOT      
    }    
  }

  tags = local.tags
}