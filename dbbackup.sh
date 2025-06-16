#!/bin/bash

BACKUP_DIR="/tmp/mongo_backups"
DATE=$(date +%F-%H%M)
FILENAME="mongo-backup-$DATE.archive.gz"
BUCKET_NAME="mongo-backup-clgcporg10-153"

mkdir -p "$BACKUP_DIR"

mongodump \
  --username admin \
  --password 'StrongPassword123' \
  --authenticationDatabase admin \
  --archive="$BACKUP_DIR/$FILENAME" \
  --gzip

gsutil cp "$BACKUP_DIR/$FILENAME" "gs://$BUCKET_NAME/"

rm "$BACKUP_DIR/$FILENAME"
