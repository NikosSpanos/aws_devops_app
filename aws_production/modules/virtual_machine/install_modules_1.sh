#! /bin/bash
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
sudo apt install -y python2.7 python-pip
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
pip install setuptools
echo "Modules installed via Terraform"