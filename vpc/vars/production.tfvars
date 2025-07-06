vpc_cidr = "10.100.0.0/16"
region = "us-east-1"
tags = {
  "kubernetes.io/cluster/eks-services-production"          = "shared"
  "kubernetes.io/role/internal-elb"                            = "1"
  "kubernetes.io/role/elb"                                     = "1"
}