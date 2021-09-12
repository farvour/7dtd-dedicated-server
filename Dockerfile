FROM ubuntu:bionic
LABEL maintainer="Thomas Farvour <tom@farvour.com>"

ARG DEBIAN_FRONTEND=noninteractive

# Top level directory where everything related to the 7dtd server
# is installed to. Since you can bind-mount data volumes for worlds,
# saves or other things, this doesn't really have to change, but is
# here for clarity and customization in case.

ENV SERVER_HOME=/app/7dtd
ENV SERVER_INSTALL_DIR=/app/7dtd/dedicated-server
ENV SERVER_DATA_DIR=/app/7dtd/data

# Steam still requires 32-bit cross compilation libraries.
RUN echo "Installing necessary system packages to support steam CLI installation..." && \
    apt-get update && \
    apt-get install -y \
    bash expect htop tmux lib32gcc1 pigz netcat telnet wget git vim && \
    rm -rf /var/lib/apt/lists/*

ENV PROC_UID 7999

RUN echo "Create a non-privileged user to run with." && \
    useradd -u ${PROC_UID} -d ${SERVER_HOME} -g nogroup z

RUN echo "Create server directories..." && \
    mkdir -p ${SERVER_HOME} && \
    mkdir -p ${SERVER_INSTALL_DIR} && \
    mkdir -p ${SERVER_INSTALL_DIR}/Mods && \
    mkdir -p ${SERVER_DATA_DIR} && \
    chown -R z ${SERVER_HOME}

USER z

WORKDIR ${SERVER_HOME}

COPY scripts/steamcmd-7dtd.script ${SERVER_HOME}/

RUN echo "Downloading and installing steamcmd..." && \
    wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz && \
    tar -zxvf steamcmd_linux.tar.gz

# This is most likely going to be the largest layer created; all the game
# files for the dedicated server. NOTE: It is a good idea to do as much as
# possible _beyond_ this point to avoid Docker having to re-create it.
RUN echo "Downloading and installing 7dtd server with steamcmd..." && \
    ${SERVER_HOME}/steamcmd.sh +runscript steamcmd-7dtd.script

# Additional system packages for everything not for the Steam installation.
# This includes Python, pipenv, and the correct Pipfile lock deployed to the
# system installation of Python 3.

USER root

RUN echo "Installing necessary system packages to support run-time and entrypoint of server..." && \
    apt-get update && \
    apt-get install -y python3 python3-dev python3-pip libbz2-dev libffi-dev libssl-dev wget && \
    rm -rf /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN echo "Ensure pipenv is installed..." \
    && python3 -V \
    && pip3 install pipenv \
    && mkdir -p /pipenv/buildroot

COPY Pipfile /pipenv/buildroot/
COPY Pipfile.lock /pipenv/buildroot/

RUN echo "Install Pipfile requirements..." \
    && python3 -V \
    && cd /pipenv/buildroot \
    && pipenv install --deploy --system

USER z

# Install the backup2l script for automatic backup assistance.
# You can simply run this script in the container and backup the mounted
# volume to a destination available on the host.

# docker run --rm --entrypoint /bin/bash -v 7dtd-dedicated-server_7dtd-data:/app/7dtd/data/Saves -v /mnt/backup:/app/7dtd/backups 7dtd-dedicated-server_7dtd-server:latest /app/7dtd/backup2l/backup2l -c /app/7dtd/backup2l/backup2l.conf -b

RUN echo "Install the backup2l tool and config..." && \
    git clone --single-branch --branch master https://github.com/gkiefer/backup2l.git && \
    if [ ! -d ${SERVER_HOME}/backups ]; then mkdir -p ${SERVER_HOME}/backups; fi

COPY --chown=z:root config/backup2l.conf ${SERVER_HOME}/backup2l/backup2l.conf

# Install custom startserver script (adds support for template tool below, etc).
COPY --chown=z:root scripts/startserver-1.sh ${SERVER_INSTALL_DIR}/

# Custom prefabs.
COPY --chown=z:root custom_prefabs/ ${SERVER_INSTALL_DIR}/Data/Prefabs/

# Mods and mods related tasks.
# COPY --chown=z:root server_fixes_v19_22_32/ ${SERVER_INSTALL_DIR}/Mods/
# COPY --chown=z:root mods/BCManager/ ${SERVER_INSTALL_DIR}/Mods/BCManager/
COPY --chown=z:root xpath_mods_src/ ${SERVER_INSTALL_DIR}/xpath_mods_src/
COPY --chown=z:root xpath_mods/ ${SERVER_INSTALL_DIR}/Mods/

# Install the start server templates tool.
COPY --chown=z:root scripts/start_server_templates.py ${SERVER_HOME}/

# Install configuration templates.
COPY --chown=z:root config/serverconfig.xml.j2 ${SERVER_HOME}/
COPY --chown=z:root config/serverconfig.xml.values.yml ${SERVER_HOME}/
COPY --chown=z:root config/serveradmin.xml.j2 ${SERVER_HOME}/
COPY --chown=z:root config/serveradmin.xml.values.yml ${SERVER_HOME}/

# Default web UI control panel port.
EXPOSE 8080/tcp

# Default telnet administrative port.
EXPOSE 8081/tcp

# Default webserver for allocs mod port.
EXPOSE 8082/tcp

# Default game ports.
EXPOSE 26900/tcp 26900/udp
EXPOSE 26901/tcp 26901/udp

# Install custom entrypoint script.
COPY scripts/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
