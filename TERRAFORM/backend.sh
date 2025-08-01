#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y docker.io

sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker ubuntu

cd /tmp
sudo docker build -t backend-app -f APP_Dockerfile.backend .
sudo docker run -d -p 5000:5000 --name backend-app backend-app

