resource "aws_service_discovery_private_dns_namespace" "local-ns" {
  name        = "local.apis.service"
  description = "Service Discovery local-ns"
  vpc         = aws_vpc.default.id
}