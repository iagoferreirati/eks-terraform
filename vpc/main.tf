provider "aws" {
  region = local.region  # Define a região AWS a ser usada, obtida da variável local
}

data "aws_availability_zones" "available" {}  # Obtém informações sobre as zonas de disponibilidade na região atual

variable "vpc_cidr" {}  # Variável para o bloco CIDR da VPC principal
variable "region" {}    # Variável para a região AWS a ser configurada
variable "tags" {       # Variável para tags que serão aplicadas nos recursos
  type = map(string)
}


locals {
  name = "eks"  # Define o nome da VPC principal baseado no diretório atual
  region = var.region                  # Atribui a região da variável para o local
  vpc_cidr = var.vpc_cidr             # Atribui o bloco CIDR da VPC principal para o local
  azs = slice(data.aws_availability_zones.available.names, 0, 3)  # Obtém os nomes das três primeiras zonas de disponibilidade na região
  tags = var.tags                     # Atribui as tags da variável para o local
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"  # Utiliza o módulo Terraform AWS para criar uma VPC
  version = "6.0.1"                         # Versão específica do módulo a ser utilizada

  name = local.name          # Nome da VPC definido localmente
  cidr = local.vpc_cidr     # Bloco CIDR da VPC definido localmente

  azs = local.azs  # Zonas de disponibilidade definidas localmente
  # Subnets privadas são criadas com blocos CIDR diferentes dentro da VPC principal
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  # Subnets públicas são criadas com blocos CIDR diferentes dentro da VPC principal
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  single_nat_gateway = true  # Usa um único gateway NAT para todas as subnets
  enable_nat_gateway = true  # Habilita o uso de NAT gateway

  private_subnet_tags = {
    private = "true"
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    public = "true"
    "kubernetes.io/role/elb" = "1"
  }

  tags = local.tags  # Aplica as tags definidas localmente aos recursos criados pela VPC
}