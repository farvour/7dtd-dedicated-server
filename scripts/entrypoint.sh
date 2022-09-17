#!/usr/bin/env bash
#
# Bootstrap entrypoint for the dedicated server.
# This script helps with any pre-bootstrap requirements
# prior to launching the actual start srever commands.

set -xe

echo
echo "Starting server..."
echo

# This comes from the Dockerfile/docker ENV.
cd ${SERVER_INSTALL_DIR}

# Invoke the server configuration file generator tool.
source ${SERVER_HOME}/.venv/bin/activate
python3 ${SERVER_HOME}/generate_server_config.py

if [ "$(id -u)" = "0" ]; then
	# Ensure ownersihp of data files.
	chown -R ${PROC_USER}:${PROC_GROUP} ${SERVER_DATA_DIR}

	echo "Dropping root privileges before invoking server..."
	exec gosu ${PROC_USER} "$@"
fi

exec "$@"
