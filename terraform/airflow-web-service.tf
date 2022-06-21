variable "airflow_webservice_container_port" {
  default = 8080
}

variable "airflow_webservice_container_name" {
  default = "airflow-webservice"
}

resource "aws_ecr_repository" "airflow-webservice-ecr" {
  name = "airflow-webservice-ecr"
}


resource "aws_ecs_task_definition" "airflow-webservice-task-defintion" {
  family                   = "airflow-webservice" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.airflow_webservice_container_name}",
      "image": "${aws_ecr_repository.airflow-webservice-ecr.repository_url}",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/service-cluster/airflow-web",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
          "retries": 3,
          "command": [
              "CMD-SHELL",
              "curl -f http://localhost:${var.airflow_webservice_container_port}/health || exit 1"
          ],
          "timeout": 10,
          "interval": 30,
          "startPeriod": 30
      },
      "secrets": [
        {
          "valueFrom": "${aws_secretsmanager_secret.airflow-db-conn-str.arn}",
          "name": "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
        },
        {
          "valueFrom": "${aws_secretsmanager_secret.airflow-result-bk-str.arn}",
          "name": "AIRFLOW__CELERY__RESULT_BACKEND" 
        },
        {
          "valueFrom": "${aws_secretsmanager_secret.airflow-result-bk-str.arn}",
          "name": "CELERY_RESULT_BACKEND" 
        },
        {
          "valueFrom": "${aws_secretsmanager_secret.api-redis-conn-str.arn}",
          "name": "AIRFLOW__CELERY__BROKER_URL" 
        },
        {
          "valueFrom": "${aws_secretsmanager_secret.api-redis-conn-str.arn}",
          "name": "CELERY_BROKER_URL" 
        }
      ],
      "portMappings": [
        {
          "containerPort": ${var.airflow_webservice_container_port}
        }
      ],
      "cpu": 256
    }
    
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 8192         # Specifying the memory our container requires
  cpu                      = 2048         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  depends_on = [
    aws_ecr_repository.airflow-webservice-ecr,
    aws_cloudwatch_log_group.airflow-webservice_cw_log_group
  ]
  # lifecycle {
  #   ignore_changes = [container_definitions]
  # }
}


resource "aws_cloudwatch_log_group" "airflow-webservice_cw_log_group" {
  name = "/ecs/service-cluster/airflow-web"
  tags = {
    Environment = "production"
    Application = "airflow-webservice"
  }
}

resource "aws_lb_target_group" "airflow-webservice_target_group" {
  name        = "airflow-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.default.id # Referencing the VPC
  deregistration_delay = 10
  health_check {
    path = "/health"
    port = "${var.airflow_webservice_container_port}"
    protocol = "HTTP"
    timeout = 20
  }
}

resource "aws_lb_listener_rule" "airflow-rule" {
  listener_arn = aws_lb_listener.secure-listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow-webservice_target_group.arn
  }

  condition {
    host_header {
      values = [var.airflow_domain]
    }
  }
}

resource "aws_security_group" "airflow-webservice_security_group" {
  vpc_id = aws_vpc.default.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
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


resource "aws_service_discovery_service" "airflow-webservice" {
  name = "web-service"

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


resource "aws_ecs_service" "airflow-webservice" {
  name            = "airflow-webservice"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.service-cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.airflow-webservice-task-defintion.arn}" # Referencing the task our service will spin up
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
  health_check_grace_period_seconds = 60

  load_balancer {
    target_group_arn = "${aws_lb_target_group.airflow-webservice_target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.airflow-webservice-task-defintion.family}"
    container_port   = "${var.airflow_webservice_container_port}" # Specifying the container port
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.api-service.arn}"
  }

  network_configuration {
    subnets          = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]
    assign_public_ip = false # Providing our containers with private IPs
    security_groups  = ["${aws_security_group.airflow-webservice_security_group.id}"] # Setting the security group
  }

  depends_on = [
    aws_ecs_cluster.service-cluster,
    aws_alb.application_load_balancer,
    aws_lb_listener_rule.airflow-rule,
    aws_ecs_cluster_capacity_providers.cluster-cp
  ]

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}

resource "aws_appautoscaling_target" "airflow-webservice_ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.service-cluster.name}/${aws_ecs_service.airflow-webservice.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.ecs-autoscale-role.arn
}


resource "aws_appautoscaling_policy" "ecs_target_cpu-airflow-webservice" {
  name               = "application-scaling-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.airflow-webservice_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.airflow-webservice_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.airflow-webservice_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.airflow-webservice_ecs_target]
}
resource "aws_appautoscaling_policy" "ecs_target_memory-airflow-webservice" {
  name               = "application-scaling-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.airflow-webservice_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.airflow-webservice_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.airflow-webservice_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.airflow-webservice_ecs_target]
}
