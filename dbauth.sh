#!/bin/bash

MONGO_ADMIN_USER="admin"
MONGO_ADMIN_PASS="StrongPassword123"

if ! grep -q "^security:" /etc/mongod.conf; then
  echo -e "\nsecurity:\n  authorization: enabled" | sudo tee -a /etc/mongod.conf
elif ! grep -q "authorization: enabled" /etc/mongod.conf; then
  sudo sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
fi

sudo systemctl restart mongod

sleep 5

mongosh <<EOF
use admin
db.createUser({
  user: "$MONGO_ADMIN_USER",
  pwd: "$MONGO_ADMIN_PASS",
  roles: [{ role: "root", db: "admin" }]
})
EOF

echo "MongoDB authorization enabled and admin user created."
echo "Username: $MONGO_ADMIN_USER"
echo "Password: $MONGO_ADMIN_PASS"
