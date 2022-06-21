
resource "aws_ecs_cluster" "service-cluster" {
  name = "service-cluster" # Naming the cluster
  depends_on = [
    aws_vpc.default
  ]
}


resource "aws_ecs_cluster_capacity_providers" "cluster-cp" {
  
  cluster_name = aws_ecs_cluster.service-cluster.name
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
  depends_on = [
    aws_ecs_cluster.service-cluster
  ]

}


resource "aws_iam_role" "ecsTaskExecutionRole" {
  name_prefix               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
    identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "secrets-role-policy" {
    role     = aws_iam_role.ecsTaskExecutionRole.id
    policy   = data.aws_iam_policy_document.secrets_role_policy.json
}

data "aws_iam_policy_document" "secrets_role_policy" {

  # Added permission for our two secrets so that ECS can fetch the values and insert into the containers
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [ 
    "${aws_secretsmanager_secret.api-redis-conn-str.arn}",
    "${aws_secretsmanager_secret.airflow-db-conn-str.arn}",
    "${aws_secretsmanager_secret.airflow-result-bk-str.arn}"
    ]
  }
}



resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs-autoscale-role" {
  name_prefix = "ecs-scale-application"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-autoscale" {
  role = aws_iam_role.ecs-autoscale-role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

#Roles and Polices required to Private Endpoint ECR to work

# resource "aws_iam_policy" "fargate_execution" {
#   name   = "fargate_execution_policy"
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [  
#     {
#         "Effect": "Allow",
#         "Action": [
#             "ecr:GetDownloadUrlForLayer",
#             "ecr:BatchGetImage",
#             "ecr:BatchCheckLayerAvailability"
#         ],
#         "Resource": "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
#     },
#     {
#         "Effect": "Allow",
#         "Action": [
#             "ecr:GetAuthorizationToken"
#         ],
#         "Resource": "*"
#     },
#     {
#         "Effect": "Allow",
#         "Action": [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream"
#         ],
#         "Resource": "*"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_policy" "fargate_task" {
#   name   = "fargate_task_policy"
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [  
#     {
#         "Effect": "Allow",
#         "Action": [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream",
#             "logs:PutLogEvents"
#         ],
#         "Resource": "*"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "fargate-execution" {
#   role     = aws_iam_role.ecsTaskExecutionRole.id
#   policy_arn = aws_iam_policy.fargate_execution.arn
# }
# resource "aws_iam_role_policy_attachment" "fargate-task" {
#   role     = aws_iam_role.ecsTaskExecutionRole.id
#   policy_arn = aws_iam_policy.fargate_task.arn
# }
