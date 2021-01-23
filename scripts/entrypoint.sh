#!/usr/bin/env bash
set -xe

echo "Starting server..."

# This comes from the Dockerfile/docker ENV.
cd ${SERVER_INSTALL_DIR}

# Invoke the server configuration file template replacement tool.
python3 ${SERVER_HOME}/start_server_templates.py

./startserver-1.sh -configfile=serverconfig.xml
