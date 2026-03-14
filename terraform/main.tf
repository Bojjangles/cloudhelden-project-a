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
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "project-a-cluster"
  cluster_version = "1.31"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets 
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    standard_nodes = {
      min_size       = 0
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.small"]

      # This gives nodes internet access to talk to Comprehend
      enable_public_ip = true 

      iam_role_additional_policies = {
        ComprehendAccess = "arn:aws:iam::aws:policy/ComprehendReadOnly"
      }
    }
  } # Closes eks_managed_node_groups
}   # Closes module "eks"

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
# ======================================================================
# CLOUDFRONT & ACM (Global CDN and SSL)
# ======================================================================

# 1. Provide an alias for us-east-1 (Mandatory for CloudFront ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Variables for the DNS setup
variable "domain_name" {
  description = "The assigned subdomain from the teacher"
  type        = string
  default     = "name.cloudhelden-projekte.de" 
}

variable "alb_dns_name" {
  description = "The AWS Load Balancer URL created by Kubernetes"
  type        = string
  default     = "k8s-default-projecta-xxx.eu-north-1.elb.amazonaws.com"
}

# 2. The ACM Certificate (Forced to us-east-1 via the provider alias)
resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 3. The CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [var.domain_name]

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # Required: HTTPS only
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API Cache Behavior (Required: Deactivate caching for /api/* with TTL=0)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    min_ttl     = 0
    default_ttl = 0 # TTL=0 ensures the backend API is always hit
    max_ttl     = 0

    forwarded_values {
      query_string = true
      headers      = ["Host"] # Required: Forward Host Header
      cookies {
        forward = "all"
      }
    }
  }

  # Default Cache Behavior (For frontend HTML/CSS/JS)
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Host"] 
      cookies {
        forward = "all"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}