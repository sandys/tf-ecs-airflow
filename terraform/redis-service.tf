variable "redis_service_container_port" {
  default = 6379
}

variable "redis_service_container_name" {
  default = "redis-service"
}

resource "aws_ecr_repository" "redis-service-ecr" {
  name = "redis-service"
}
//"image": "${aws_ecr_repository.redis-service-ecr.repository_url}",
resource "aws_ecs_task_definition" "redis-service-task-defintion" {
  family                   = "redis-service" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.redis_service_container_name}",
      "image": "${aws_ecr_repository.redis-service-ecr.repository_url}",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/redis-service",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
          "retries": 3,
          "command": [
              "CMD-SHELL",
              "redis-cli ping || exit 1"
          ],
          "timeout": 10,
          "interval": 30,
          "startPeriod": 30
      },
      "portMappings": [
        {
          "containerPort": ${var.redis_service_container_port}
        }
      ],
      "memory": 512,
      "cpu": 256
    }
    
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  depends_on = [
    aws_ecr_repository.redis-service-ecr,
    aws_cloudwatch_log_group.redis-service_cw_log_group
  ]
  lifecycle {
    ignore_changes = [container_definitions]
  }
}


resource "aws_cloudwatch_log_group" "redis-service_cw_log_group" {
  name = "/ecs/redis-service"
  tags = {
    Environment = "production"
    Application = "redis-service"
  }
}


resource "aws_security_group" "redis-service_security_group" {
  vpc_id = aws_vpc.default.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0"]
  }

  #   egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  # }
}

resource "aws_service_discovery_service" "redis-service" {
  name = "redis-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local-ns.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_ecs_service" "redis-service" {
  name            = "redis-service"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.service-cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.redis-service-task-defintion.arn}" # Referencing the task our service will spin up
  #Place atleast 1 task as OD and for each 1:4 place rest autoscaling for each 1 OD to 4 SPOT
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight = 1
    base = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 4
  }
  
# Break the deployment if new tasks are not able to run and revert back to previous state

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  desired_count   = 1 # Setting the number of containers to 1

  network_configuration {
    subnets          = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]
    assign_public_ip = false # Providing our containers with private IPs
    security_groups  = ["${aws_security_group.redis-service_security_group.id}"] # Setting the security group
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.redis-service.arn}"
  }

  depends_on = [
    aws_ecs_cluster.service-cluster,
    aws_ecs_cluster_capacity_providers.cluster-cp
  ]

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}

resource "aws_appautoscaling_target" "redis-service_ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.service-cluster.name}/${aws_ecs_service.redis-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.ecs-autoscale-role.arn
}


resource "aws_appautoscaling_policy" "ecs_target_cpu-redis-service" {
  name               = "application-scaling-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.redis-service_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.redis-service_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.redis-service_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.redis-service_ecs_target]
}
resource "aws_appautoscaling_policy" "ecs_target_memory-redis-service" {
  name               = "application-scaling-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.redis-service_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.redis-service_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.redis-service_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.redis-service_ecs_target]
}
