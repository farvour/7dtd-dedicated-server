#!/usr/bin/env bash
set -xe

echo "Starting server..."

# This comes from the Dockerfile/docker ENV.
cd ${SERVER_INSTALL_DIR}

# Copy and dereference any link/symlink that might come from k8s, etc
# on a volume mount. The server is very particular when it opens this file...
if [ -f serverconfig1/serverconfig.xml ]; then
    cp -Lf serverconfig1/serverconfig.xml serverconfig.xml
fi

./startserver-1.sh -configfile=serverconfig.xml
