vpc_cidr = "10.100.0.0/16"
region = "us-east-1"
tags = {
  "kubernetes.io/cluster/iago-services-production"          = "shared"
  "kubernetes.io/role/internal-elb"                            = "1"
  "kubernetes.io/role/elb"                                     = "1"
}

################################################################################

vpc_cidr_services = "10.10.0.0/16"
tags_services = {}
