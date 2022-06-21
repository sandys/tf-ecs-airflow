# data "aws_region" "current" {}
# data "aws_caller_identity" "current" {}


# resource "aws_security_group" "vpc_endpoint_security_group" {
#   vpc_id = aws_vpc.default.id
#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     security_groups = [aws_security_group.airflow-celeryworker-service_security_group.id, aws_security_group.airflow-scheduler-service_security_group.id, aws_security_group.airflow-webservice_security_group.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   depends_on = [
#     aws_vpc.default
#   ]
# }


# resource "aws_vpc_endpoint" "s3" {
#   vpc_id            = aws_vpc.default.id
#   service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
#   auto_accept = true
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [aws_route_table.private[0].id, aws_route_table.private[0].id]

#   tags = {
#     Name        = "s3-endpoint"
#     Environment = "production"
#   }
# }

# resource "aws_vpc_endpoint" "dkr" {
#   vpc_id              = aws_vpc.default.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
#   auto_accept = true
#   vpc_endpoint_type   = "Interface"
#   security_group_ids = [
#     aws_security_group.vpc_endpoint_security_group.id
#   ]
#   subnet_ids = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]

#   tags = {
#     Name        = "dkr-endpoint"
#     Environment = "production"
#   }
# }

# resource "aws_vpc_endpoint" "ecr-api" {
#   vpc_id              = aws_vpc.default.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
#   auto_accept = true
#   vpc_endpoint_type   = "Interface"
#   security_group_ids = [
#     aws_security_group.vpc_endpoint_security_group.id
#   ]
#   subnet_ids = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]

#   tags = {
#     Name        = "ecr-api-endpoint"
#     Environment = "production"
#   }
# }

# resource "aws_vpc_endpoint" "rds" {
#   vpc_id              = aws_vpc.default.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.rds"
#   auto_accept = true
#   vpc_endpoint_type   = "Interface"
#   security_group_ids = [
#     aws_security_group.vpc_endpoint_security_group.id
#   ]
#   subnet_ids = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]

#   tags = {
#     Name        = "rds-endpoint"
#     Environment = "production"
#   }
# }


# resource "aws_vpc_endpoint" "secrets" {
#   vpc_id              = aws_vpc.default.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
#   auto_accept = true
#   vpc_endpoint_type   = "Interface"
#   security_group_ids = [
#     aws_security_group.vpc_endpoint_security_group.id
#   ]
#   subnet_ids = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]

#   tags = {
#     Name        = "secrets-endpoint"
#     Environment = "production"
#   }
# }



# resource "aws_vpc_endpoint" "logs" {
#   vpc_id              = aws_vpc.default.id
#   private_dns_enabled = true
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
#   auto_accept = true
#   vpc_endpoint_type   = "Interface"
#   security_group_ids = [
#     aws_security_group.vpc_endpoint_security_group.id
#   ]
#   subnet_ids = ["${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"]

#   tags = {
#     Name        = "logs-endpoint"
#     Environment = "production"
#   }
# }