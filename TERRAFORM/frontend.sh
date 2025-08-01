#!/bin/bash
#sudo yum update -y
#sudo amazon-linux-extras install docker -y
#sudo service docker start
#sudo usermod -a -G docker ec2-user
#docker pull <kanhax04>/frontend
#docker run -d -p 80:80 <kanhax04>/frontend

#!/bin/bash

FRONTEND_DOCKER_IMAGE=$1
FRONTEND_APP_PORT=$2
BACKEND_PRIVATE_IP=$3

sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on

sudo docker run -d -p ${FRONTEND_APP_PORT}:${FRONTEND_APP_PORT} \
  -e BACKEND_IP=${BACKEND_PRIVATE_IP} \
  --name frontend-app \
  ${FRONTEND_DOCKER_IMAGE}
