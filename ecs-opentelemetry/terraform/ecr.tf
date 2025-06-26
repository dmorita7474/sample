
resource "aws_ecr_repository" "nextjs" {
  name = "nextjs-app"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire untagged images after 14 days",
        selection    = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "fastapi" {
  name = "fastapi-app"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire untagged images after 14 days",
        selection    = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
