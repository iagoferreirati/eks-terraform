region = "us-east-1"

vpc_cidr = "10.200.0.0/16"
tags = {
  "kubernetes.io/cluster/eks-services-development"          = "shared"
  "kubernetes.io/role/internal-elb"                            = "1"
  "kubernetes.io/role/elb"                                     = "1"
}