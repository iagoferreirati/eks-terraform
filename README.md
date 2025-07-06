# EKS Terraform Infrastructure

Este projeto utiliza Terraform para provisionar uma infraestrutura AWS completa com VPC e cluster EKS (Elastic Kubernetes Service).

## 📋 Pré-requisitos

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.29
- [AWS IAM Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)

## 🏗️ Arquitetura

O projeto está organizado em dois módulos principais:

### 1. VPC (`vpc/`)
- Cria duas VPCs separadas:
  - **VPC Principal**: Para o cluster EKS (`10.200.0.0/16`)
  - **VPC Services**: Para serviços adicionais (`10.20.0.0/16`)
- Subnets públicas e privadas em 3 zonas de disponibilidade
- NAT Gateway para conectividade das subnets privadas
- Tags adequadas para integração com EKS

### 2. EKS (`eks/`)
- Cluster EKS versão 1.29
- Node groups com instâncias t3.medium
- Add-ons configurados:
  - CoreDNS
  - kube-proxy
  - VPC CNI (com prefix delegation)
  - AWS EBS CSI Driver
- Suporte a EFA (Elastic Fabric Adapter)
- Volumes EBS GP3 de 100GB

## 🚀 Como Executar

### 1. Configurar AWS Credentials

```bash
aws configure
```

Ou configure as variáveis de ambiente:

```bash
export AWS_ACCESS_KEY_ID="sua_access_key"
export AWS_SECRET_ACCESS_KEY="sua_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2. Deploy da VPC

```bash
# Navegar para o diretório VPC
cd vpc

# Inicializar Terraform
terraform init

# Verificar o plano de execução
terraform plan -var-file="vars/development.tfvars"

# Aplicar a configuração
terraform apply -var-file="vars/development.tfvars"
```

### 3. Configurar VPC ID e Subnet IDs

Após o deploy da VPC, você precisa atualizar o arquivo `eks/vars/development.tfvars` com os IDs gerados:

```hcl
vpc_id = "vpc-xxxxxxxxx"  # ID da VPC criada
subnet_ids = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]  # IDs das subnets públicas
subnet_ids_private = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]  # IDs das subnets privadas
```

### 4. Deploy do EKS

```bash
# Navegar para o diretório EKS
cd eks

# Inicializar Terraform
terraform init

# Verificar o plano de execução
terraform plan -var-file="vars/development.tfvars"

# Aplicar a configuração
terraform apply -var-file="vars/development.tfvars"
```

### 5. Configurar kubectl

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name iago-services-development

# Verificar conexão
kubectl get nodes
```

## 🔧 Configurações por Ambiente

### Development
- **Arquivo**: `vars/development.tfvars`
- **Região**: us-east-1
- **VPC CIDR**: 10.200.0.0/16
- **Cluster Name**: iago-services-development

### Production
- **Arquivo**: `vars/production.tfvars`
- Configure conforme necessário para produção

## 🗂️ Estrutura do Projeto

```
eks-terraform/
├── vpc/
│   ├── main.tf
│   ├── backend.tf
│   ├── README.md
│   └── vars/
│       ├── development.tfvars
│       └── production.tfvars
├── eks/
│   ├── main.tf
│   ├── backend.tf
│   ├── README.md
│   └── vars/
│       ├── development.tfvars
│       └── production.tfvars
└── README.md
```

## 🧹 Limpeza

Para destruir a infraestrutura:

```bash
# Destruir EKS primeiro
cd eks
terraform destroy -var-file="vars/development.tfvars"

# Depois destruir VPC
cd ../vpc
terraform destroy -var-file="vars/development.tfvars"
```

## 🔒 Segurança

- Todas as instâncias EKS usam AMIs otimizadas da AWS
- Volumes EBS são criptografados
- Subnets privadas para workloads sensíveis
- NAT Gateway para controle de tráfego de saída

## 📊 Monitoramento

Após o deploy, você pode:

1. **Verificar o cluster**:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

2. **Acessar o Dashboard EKS**:
   - Vá para o console AWS > EKS
   - Selecione o cluster
   - Clique em "View cluster"

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request