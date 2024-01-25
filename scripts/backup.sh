#!/usr/bin/env bash
#
# Runs backup from within the container to bind mounted backup volume.
#

set -xe

: ${LOCAL_BACKUP_MOUNT_PATH:="/mnt/data/backup/7dtd"}

docker run \
    --rm \
    --entrypoint /bin/bash \
		--volume 7dtd_data:/var/opt/7dtd/data/Saves \
		--volume ${LOCAL_BACKUP_MOUNT_PATH}:/opt/7dtd/backups \
		7dtd-server /opt/7dtd/backup2l/backup2l \
		-c /opt/7dtd/backup2l/backup2l.conf "$@"
