#!/bin/bash

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 429877192616.dkr.ecr.us-west-2.amazonaws.com
docker build -t airflow-scheduler-service-ecr -f Dockerfile.scheduler .
docker tag airflow-scheduler-service-ecr:latest 429877192616.dkr.ecr.us-west-2.amazonaws.com/airflow-scheduler-service-ecr:latest
docker push 429877192616.dkr.ecr.us-west-2.amazonaws.com/airflow-scheduler-service-ecr:latest