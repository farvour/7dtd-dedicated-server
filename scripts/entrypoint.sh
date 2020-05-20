#!/usr/bin/env bash
set -xe

echo "Starting server..."

cd ${SERVER_INSTALL_DIR}
./startserver-1.sh -configfile=serverconfig.xml
