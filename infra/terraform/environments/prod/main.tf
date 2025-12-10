terraform {
  required_version = ">= 1.0"
  backend "s3" {
    bucket  = "devops-exam-terraform-state-bucket-1234"
    key     = "prod/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Networking Module
module "networking" {
  source = "../../modules/networking"
  
  prefix          = var.prefix
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  prefix             = var.prefix
  environment        = var.environment
  aws_region         = var.aws_region
  cluster_version    = var.cluster_version
  node_instance_type = var.node_instance_type
  desired_capacity   = var.desired_capacity
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnets
}

# Storage Module
module "storage" {
  source = "../../modules/storage"
  
  prefix      = var.prefix
  environment = var.environment
  
  email_processor_role_arn = module.eks.email_processor_service_role_arn
}

# Messaging Module
module "messaging" {
  source = "../../modules/messaging"
  
  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region
  
  email_validation_role_arn = module.eks.email_validation_service_role_arn
  email_processor_role_arn  = module.eks.email_processor_service_role_arn
  email_validation_token    = var.email_validation_token
}

# Configure Kubernetes and Helm providers
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", module.eks.cluster_name]
    }
  }
}