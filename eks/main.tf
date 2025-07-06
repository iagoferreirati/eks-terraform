provider "aws" {
  region = local.region  # Define a região AWS onde os recursos serão provisionados
}

# Busca a VPC pelo nome
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["eks"]
  }
}

# Busca as subnets privadas
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]  # Referencia o VPC ID obtido na consulta anterior
  }
  
  filter {
    name   = "tag:private"
    values = ["true"]  # Subnets com a tag "private=true"
  }
}


# Obtém a imagem mais recente para o nó do cluster EKS com arquitetura ARM64
data "aws_ami" "eks_default_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-arm64-standard-1.33-v*"]
  }
}

# Obtém a imagem mais recente para o nó do cluster EKS com arquitetura x86_64
data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-1.33-v*"]
  }
}

# Definição de variáveis de entrada
variable "name" {}
variable "region" {}
variable "instance_types_service_arm_64" {
  type = list(string)
}
variable "instance_types_service" {
  type = list(string)
}

# Definições locais
locals {
  name            = var.name  # Nome do cluster EKS
  cluster_version = "1.33"    # Versão do cluster EKS
  region          = var.region

  # Tags para recursos, incluindo identificação do cluster EKS
  tags = {
    "kubernetes.io/cluster/${var.name}"          = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
    "eks/cluster/${var.name}/node_group/default" = "true"
  }
}

# Módulo EKS
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name                   = local.name  # Nome do cluster
  cluster_version                = local.cluster_version  # Versão do cluster
  cluster_endpoint_public_access = true  # Permite acesso público ao endpoint do cluster

  # IPV6
  cluster_ip_family = "ipv4"  # Define o uso de IPV4 para o cluster

  enable_cluster_creator_admin_permissions = true  # Permite permissões administrativas para o criador do cluster

  # Habilita o suporte ao EFA (Elastic Fabric Adapter) para grupos de nós
  enable_efa_support = true

  # Configuração de add-ons do EKS
  cluster_addons = {
    coredns = {
      addon_version = "v1.12.1-eksbuild.2"  # Versão do add-on CoreDNS
      resolve_conflicts="PRESERVE"  # Resolve conflitos preservando a configuração atual
    }
    kube-proxy = {
      addon_version = "v1.33.0-eksbuild.2"  # Versão do add-on Kube-Proxy
      resolve_conflicts="PRESERVE"  # Resolve conflitos preservando a configuração atual
    }
    vpc-cni = {
      addon_version = "v1.19.5-eksbuild.3"  # Versão do add-on VPC CNI (Network Interface)
      resolve_conflicts="PRESERVE"  # Resolve conflitos preservando a configuração atual
      before_compute = true  # Aplica a configuração antes do início do cálculo
      configuration_values = jsonencode({
        env = {
          # Referência de documentos: https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"  # Habilita a delegação de prefixo
          WARM_PREFIX_TARGET       = "1"     # Define o número alvo de prefixos quentes
        }
      })
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.37.0-eksbuild.1"  # Versão do driver AWS EBS CSI
      resolve_conflicts="PRESERVE"  # Resolve conflitos preservando a configuração atual
    }        
  }

  # Configuração da VPC e subnets do cluster
  vpc_id     = data.aws_vpc.main.id  # ID da VPC para o cluster EKS
  subnet_ids = data.aws_subnets.private.ids  # IDs das subnets associadas ao cluster

  # Configuração de grupos de nós gerenciados pelo EKS
  eks_managed_node_groups = {
    # Exemplo de grupo de nós para arquitetura x86_64 (comentado)
    # services_arm_64 = {
    #   ami_type = "AL2_x86_64"  # Tipo de AMI para arquitetura x86_64
    #   ami_id       = data.aws_ami.eks_default_arm.image_id  # ID da imagem do EKS para ARM64
    #   min_size     = 1  # Tamanho mínimo do grupo de nós
    #   max_size     = 4  # Tamanho máximo do grupo de nós
    #   desired_size = 1  # Tamanho desejado do grupo de nós
    #   enable_bootstrap_user_data = true  # Habilita o uso de dados de bootstrap para os nós
    #   subnet_ids                 = var.subnet_ids_private  # IDs das subnets privadas para os nós
    #   instance_types             = var.instance_types_service_arm_64  # Tipos de instâncias para os nós
    # }
    
    # Grupo de nós para serviços usando a arquitetura x86_64
    services = {
      ami_type = "AL2023_x86_64_STANDARD"  # Tipo de AMI para arquitetura x86_64
      ami_id       = data.aws_ami.eks_default.image_id  # ID da imagem do EKS para x86_64
      min_size     = 2  # Tamanho mínimo do grupo de nós
      max_size     = 4  # Tamanho máximo do grupo de nós
      desired_size = 2  # Tamanho desejado do grupo de nós
      enable_bootstrap_user_data = true  # Habilita o uso de dados de bootstrap para os nós
      subnet_ids                 = data.aws_subnets.private.ids  # IDs das subnets privadas para os nós
      instance_types             = var.instance_types_service  # Tipos de instâncias para os nós
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"  # Nome do dispositivo para o volume EBS
          ebs = {
            volume_size           = 30  # Tamanho do volume em GB
            volume_type           = "gp3"  # Tipo do volume (gp3)
            iops                  = 3000  # Número de IOPS
            throughput            = 150  # Largura de banda do volume
            encrypted             = true  # Habilita a criptografia do volume
            delete_on_termination = true  # Exclui o volume quando o nó é excluído
          }
        }
      }  
      bootstrap_extra_args = <<-EOT
        --use-max-pods false  # Configura o uso de pods máximos
      EOT      
    }    
  }

  # Aplicando tags aos recursos do EKS
  tags = local.tags  # Tags definidas localmente
}