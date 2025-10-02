#!/bin/bash
yum update -y
yum install -y docker
systemctl enable docker --now
docker run -d -p 8080:80 nginx