#!/usr/bin/env bash
set -xe

exec ${SERVER_INSTALL_DIR}/startserver-1.sh -configfile=serverconfig.xml
