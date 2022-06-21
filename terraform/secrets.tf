resource "aws_secretsmanager_secret" "airflow-db-conn-str" {
  name = "airflow-db"
}

resource "aws_secretsmanager_secret" "airflow-result-bk-str" {
  name = "airflow-result-bk"
}

resource "aws_secretsmanager_secret" "api-redis-conn-str" {
  name = "api-redis"
}