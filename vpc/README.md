
# Terraform VPC Configuration

Este projeto configura uma VPC na AWS usando o Terraform, criando subnets privadas e públicas em várias zonas de disponibilidade.

## Descrição

Este módulo Terraform cria uma VPC com:

- Subnets privadas e públicas
- Configuração de NAT Gateway
- Tags configuráveis para recursos

O código utiliza o módulo `terraform-aws-modules/vpc/aws` para a criação da VPC.

## Variáveis

### `vpc_cidr`
Bloco CIDR da VPC principal.

```hcl
variable "vpc_cidr" {}
```

### `region`
A região da AWS onde os recursos serão provisionados.

```hcl
variable "region" {}
```

### `tags`
Tags para aplicar aos recursos da VPC.

```hcl
variable "tags" {
  type = map(string)
}
```

### `vpc_cidr_services`
Bloco CIDR para a VPC de serviços.

```hcl
variable "vpc_cidr_services" {}
```

### `tags_services`
Tags específicas para os recursos de serviços.

```hcl
variable "tags_services" {
  type = map(string)
}
```

## Configuração Local

A configuração local define variáveis derivadas, como o nome da VPC, zonas de disponibilidade e tags. Estas variáveis são usadas para personalizar a criação dos recursos.

```hcl
locals {
  name   = "eks-${basename(path.cwd)}"
  region = var.region
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = var.tags

  name_services   = "services-${basename(path.cwd)}"
  vpc_cidr_services = var.vpc_cidr_services
  azs_services      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags_services = var.tags_services  
}
```

## Função `cidrsubnet`

A função `cidrsubnet` é usada para dividir o bloco CIDR da VPC em sub-redes. A expressão `cidrsubnet(local.vpc_cidr, 4, k)` é responsável por criar subnets privadas para as zonas de disponibilidade.

### Explicação da Função `cidrsubnet`

```hcl
private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
```

A função `cidrsubnet` tem três parâmetros:

1. **Bloco CIDR base**: O bloco CIDR da VPC, neste caso, `local.vpc_cidr`, que pode ser algo como `10.0.0.0/16`.
2. **Número de bits para sub-redes**: O valor `4` indica que a máscara de rede será aumentada de `16` para `20 bits`, permitindo a criação de sub-redes com uma maior granularidade.
3. **Índice de zona de disponibilidade**: O valor `k` é o índice da zona de disponibilidade (AZ), que vai de `0` a `2` no caso de três AZs. Esse valor é usado para calcular a subnet correspondente à zona de disponibilidade.

O que acontece é o seguinte:
- Para a zona de disponibilidade `0`, `k = 0`, a subnet será gerada a partir do CIDR base, criando um bloco de rede como `10.0.0.0/20`.
- Para a zona de disponibilidade `1`, `k = 1`, a subnet será gerada com um bloco CIDR como `10.0.16.0/20`.
- Para a zona de disponibilidade `2`, `k = 2`, a subnet será gerada com um bloco CIDR como `10.0.32.0/20`.

Isso garante que cada zona de disponibilidade tenha uma subnet única dentro do bloco CIDR da VPC, com a máscara de rede ajustada para permitir o número desejado de sub-redes.

## Criação das Subnets

O código cria subnets privadas e públicas dentro da VPC com base no bloco CIDR fornecido.

### Subnets Privadas

As subnets privadas são geradas utilizando a função `cidrsubnet` para dividir o bloco CIDR da VPC principal. Cada zona de disponibilidade recebe uma subnet privada.

```hcl
private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
```

- **`cidrsubnet(local.vpc_cidr, 4, k)`**: A função `cidrsubnet` cria uma subnet para cada zona de disponibilidade. O número `4` indica o número de bits a serem usados para aumentar a máscara de rede de `16` para `20` bits, permitindo a criação de sub-redes.

### Subnets Públicas

As subnets públicas são criadas de forma semelhante, mas com um deslocamento de 8 unidades para garantir que os blocos CIDR das subnets públicas não se sobreponham aos das subnets privadas. O cálculo `k + 8` é usado para isso.

```hcl
public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]
```

- **`cidrsubnet(local.vpc_cidr, 4, k + 8)`**: A expressão `k + 8` desloca os blocos CIDR usados para as subnets públicas. O valor de `k` é o índice da zona de disponibilidade (0, 1, 2) e, ao adicionar 8, garantimos que as subnets públicas fiquem em blocos CIDR separados.

## Módulo VPC

A configuração do módulo VPC utiliza o módulo oficial `terraform-aws-modules/vpc/aws` para criar a VPC com as subnets públicas e privadas.

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"
  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  single_nat_gateway = true
  enable_nat_gateway = true

  tags = local.tags
}
```

- **`azs`**: Zonas de disponibilidade onde as subnets serão criadas.
- **`private_subnets`**: Subnets privadas usando o bloco CIDR calculado.
- **`public_subnets`**: Subnets públicas usando o bloco CIDR calculado com deslocamento de `k + 8`.
- **`single_nat_gateway`**: Define que um único NAT Gateway será usado para todas as subnets.
- **`enable_nat_gateway`**: Habilita o uso do NAT Gateway.
- **`tags`**: Aplica as tags configuradas aos recursos.

## Conclusão

Este projeto cria uma VPC na AWS com subnets privadas e públicas distribuídas em múltiplas zonas de disponibilidade. Ele usa o módulo oficial do Terraform para facilitar a configuração e garantir uma infraestrutura escalável e bem configurada.

Para utilizar este código, basta definir as variáveis adequadas e aplicar o Terraform para provisionar os recursos na AWS.

```bash
terraform init
terraform apply
```
