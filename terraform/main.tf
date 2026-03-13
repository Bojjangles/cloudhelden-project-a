# terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Locked to v5 to avoid all bugs!
    }
  }
}

provider "aws" {
  region = "eu-north-1" # Changed from eu-central-1 to Stockholm!
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "project-a-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  map_public_ip_on_launch = true
  enable_nat_gateway      = false
  single_nat_gateway      = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "project-a-cluster"
  cluster_version = "1.31"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets 
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    standard_nodes = {
      min_size     = 0
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.small"] 
      iam_role_additional_policies = {
        ComprehendAccess = "arn:aws:iam::aws:policy/ComprehendReadOnly"
      }
    }
  }
}

# 1. Create a DB Subnet Group (Required for RDS in a VPC)
resource "aws_db_subnet_group" "rds" {
  name       = "project-a-rds-group"
  subnet_ids = module.vpc.private_subnets # Must be in Private Subnets 

  tags = { Name = "Project A RDS Subnet Group" }
}

# 2. The RDS Instance
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro" # Mandatory size [cite: 87]
  db_name              = "feedbackdb"
  username             = "dbadmin"
  password             = "Password123!" # In a real project, use Secrets Manager! [cite: 66]
  parameter_group_name = "default.postgres16"
  skip_final_snapshot  = true

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# 3. Security Group for RDS (Only allow EKS to talk to it)
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow EKS nodes to access RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # Only EKS nodes can enter 
  }
}

# 4. Output the Endpoint (We need this for the backend code!)
output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}