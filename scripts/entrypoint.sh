#!/usr/bin/env bash
set -xe

echo "Starting server..."

# This comes from the Dockerfile/docker ENV.
cd ${SERVER_INSTALL_DIR}

# Invoke the server configuration file generator tool.
source ${SERVER_HOME}/.venv/bin/activate
python3 ${SERVER_HOME}/generate_server_config.py

./startserver-1.sh -configfile=serverconfig.xml
