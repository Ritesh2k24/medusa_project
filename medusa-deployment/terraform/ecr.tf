resource "aws_ecr_repository" "medusa_repo" {
  name = var.ecr_repository_name
}
