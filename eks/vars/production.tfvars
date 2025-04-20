name = "iago-services-production"
vpc_cidr = "10.100.0.0/16"
vpc_id  = "vpc-"
subnet_ids = ["subnet-", "subnet-", "subnet-"]
instance_types_service_arm_64 = ["t4g.medium"]
instance_types_service = ["t3.large"]
subnet_ids_private = ["subnet-", "subnet-"]
region = "sa-east-1"