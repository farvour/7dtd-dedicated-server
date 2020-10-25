FROM ubuntu:bionic
LABEL maintainer="Thomas Farvour <tom@farvour.com>"

ARG DEBIAN_FRONTEND=noninteractive

# Top level directory where everything related to the 7dtd server is installed to.
# Since you can bind-mount data volumes for worlds, saves or other things, this
# doesn't really have to change, but is here for clarity and customization in case.
ENV SERVER_HOME=/app/7dtd
ENV SERVER_INSTALL_DIR=/app/7dtd/dedicated-server
ENV SERVER_DATA_DIR=/app/7dtd/data

# Steam still requires 32-bit cross compilation libraries.
RUN echo "Installing necessary system packages to support steam CLI installation..." && \
    apt-get update && \
    apt-get install -y bash expect htop tmux lib32gcc1 pigz telnet wget git && \
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

# This is most likely going to be the largest layer created; all the game files for the dedicated server.
# NOTE: It is a good idea to do as much as possible _beyond_ this point to avoid Docker having to re-create it.
RUN echo "Downloading and installing 7dtd server with steamcmd..." && \
    ${SERVER_HOME}/steamcmd.sh +runscript steamcmd-7dtd.script

# Install the backup2l script for automatic backup assistance.
# You can simply run this script in the container and backup the mounted volume to a destination available on the host.
# docker run --rm --entrypoint /bin/bash dedicated-server_7dtd-server:latest -v dedicated-server_7dtd-data:/app/7dtd/data/Saves -v /mnt/backup:/app/7dtd/backups /app/7dtd/backup2l/backup2l -c /app/7dtd/backup2l/backup2l.conf -b
RUN echo "Install the backup2l tool and config..." && \
    git clone --single-branch --branch master https://github.com/gkiefer/backup2l.git && \
    if [ ! -d ${SERVER_HOME}/backups ]; then mkdir -p ${SERVER_HOME}/backups; fi

COPY --chown=z:root config/backup2l.conf ${SERVER_HOME}/backup2l/backup2l.conf

# Install custom startserver script.
COPY --chown=z:root scripts/startserver-1.sh ${SERVER_INSTALL_DIR}/

# Custom prefabs.
COPY --chown=z:root custom_prefabs/ ${SERVER_INSTALL_DIR}/Data/Prefabs/

# Install custom configuration.
COPY --chown=z:root config/serverconfig.xml ${SERVER_INSTALL_DIR}/

# Mods and mods related tasks.
# COPY --chown=z:root server_fixes_v19_22_32/ ${SERVER_INSTALL_DIR}/Mods/
COPY --chown=z:root mods/BCManager/ ${SERVER_INSTALL_DIR}/Mods/BCManager/
COPY --chown=z:root xpath_mods_src/ ${SERVER_INSTALL_DIR}/xpath_mods_src/
COPY --chown=z:root xpath_mods/ ${SERVER_INSTALL_DIR}/Mods/

# Default web UI control panel port.
EXPOSE 8080/tcp

# Default telnet administrative port.
EXPOSE 8081/tcp

# Default webserver for allocs mod port.
EXPOSE 8082/tcp

# Default game port.
EXPOSE 26900/tcp
EXPOSE 26900/udp
EXPOSE 26901/tcp
EXPOSE 26901/udp

# Install custom entrypoint script.
COPY scripts/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
