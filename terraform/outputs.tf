output "aws_vpc_id" {
    value = aws_vpc.default.id
}

output "ecsTaskExecutionRole_arn" {
    value = aws_iam_role.ecsTaskExecutionRole.arn
}

output "service-alb-dnsname-to-be-added-to-namecheap" {
    value = aws_alb.application_load_balancer.dns_name
}

output "cluster_name" {
    value = aws_ecs_cluster.service-cluster.name
}


output "airflow-endpoint" {
    value = "https://${var.airflow_domain}/"
}

output "api-service-endpoint" {
   value = "https://${var.api_domain}/"
}

output "dns-records-for-ssl" {
  value = "${aws_acm_certificate.ssl-cert.domain_validation_options}"
}

