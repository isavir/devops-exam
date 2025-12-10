# ECR Repository for all microservices
resource "aws_ecr_repository" "microservices" {
  name                 = "${var.prefix}-microservices"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.prefix}-microservices"
    Environment = "production"
  }
}
