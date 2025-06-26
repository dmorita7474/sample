
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "ecs-opentelemetry-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "6.0.0"

  cluster_name = "ecs-opentelemetry-cluster"
  vpc_id       = module.vpc.vpc_id
}

data "aws_availability_zones" "available" {}
