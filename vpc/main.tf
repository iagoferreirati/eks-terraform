provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

variable "vpc_cidr" {}
variable "region" {}
variable "tags" {
  type        = map(string)
}

variable "vpc_cidr_services" {}
variable "tags_services" {
  type        = map(string)
}


locals {
  name   = "eks-${basename(path.cwd)}"
  region = var.region
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = var.tags

################################################################################

  name_services   = "services-${basename(path.cwd)}"
  vpc_cidr_services = var.vpc_cidr_services
  azs_services      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags_services = var.tags_services  
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  single_nat_gateway = true
  enable_nat_gateway = true

  tags = local.tags
}

module "vpc_services" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  name = local.name_services
  cidr = local.vpc_cidr_services

  azs             = local.azs_services
  private_subnets = [for k, v in local.azs_services : cidrsubnet(local.vpc_cidr_services, 4, k)]
  public_subnets  = [for k, v in local.azs_services : cidrsubnet(local.vpc_cidr_services, 4, k + 8)]

  single_nat_gateway = true
  enable_nat_gateway = true

  tags = local.tags_services
}