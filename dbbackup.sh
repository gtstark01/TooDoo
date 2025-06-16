#!/bin/bash

# CONFIG
BACKUP_DIR="/tmp/mongo_backups"
DATE=$(date +%F-%H%M)
FILENAME="mongo-backup-$DATE.archive.gz"
BUCKET_NAME="mongo-backup-clgcporg10-153"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Dump all databases with authentication and compress
mongodump \
  --username admin \
  --password 'StrongPassword123' \
  --authenticationDatabase admin \
  --archive="$BACKUP_DIR/$FILENAME" \
  --gzip

# Upload to GCS
gsutil cp "$BACKUP_DIR/$FILENAME" "gs://$BUCKET_NAME/"

# Cleanup
rm "$BACKUP_DIR/$FILENAME"
