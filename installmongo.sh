#!/bin/bash
set -e

cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

sudo yum install -y \
  mongodb-org-7.0.0 \
  mongodb-org-database-7.0.0 \
  mongodb-org-server-7.0.0 \
  mongodb-mongosh \
  mongodb-org-mongos-7.0.0 \
  mongodb-org-tools-7.0.0 \
  mongodb-org-database-tools-extra-7.0.0

sudo systemctl start mongod
sudo systemctl enable mongod

echo "MongoDB 7.0 installed and mongod service started."
