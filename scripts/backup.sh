#!/usr/bin/env bash
#
# Runs backup from within the container to bind mounted backup volume.
#

set -xe

: ${LOCAL_BACKUP_MOUNT_PATH:="/mnt/backup/z/7DaysToDieDataBackup"}

docker run \
    --rm \
    --entrypoint /bin/bash \
    --mount source=dedicated-server_7dtd-data,destination=/app/7dtd/data/Saves \
    --volume ${LOCAL_BACKUP_MOUNT_PATH}:/app/7dtd/backups \
    dedicated-server_7dtd-server:latest \
    /app/7dtd/backup2l/backup2l \
    -c /app/7dtd/backup2l/backup2l.conf -b
