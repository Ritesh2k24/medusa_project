#############################
# ECS Cluster
#############################
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

#############################
# IAM Role for ECS Task Execution
#############################
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#############################
# ECS Task Definition (Fargate)
#############################
resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "medusa",
      image     = "${aws_ecr_repository.medusa_repo.repository_url}:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 9000,
          hostPort      = 9000,
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "NODE_ENV",
          value = "production"
        }
        // Add other environment variables as needed (e.g., DATABASE_URL)
      ]
    }
  ])
}

#############################
# ECS Service
#############################
resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]  # Use public subnet to get direct internet access
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true  # Enable public IP assignment for direct access
  }
}

#############################
# Security Group for ECS Tasks
#############################
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medusa-ecs-sg"
  }
}
