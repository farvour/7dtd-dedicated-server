FROM ubuntu:bionic
LABEL maintainer="Thomas Farvour <tom@farvour.com>"

ARG DEBIAN_FRONTEND=noninteractive

# Top level directory where everything related to the 7dtd server is installed to.
# Since you can bind-mount data volumes for worlds, saves or other things, this
# doesn't really have to change, but is here for clarity and customization in case.
ENV SERVER_HOME=/zed
ENV SERVER_INSTALL_DIR=/zed/7dtd-dedicated-server
ENV SERVER_DATA_DIR=/zed/7dtd-data

# Steam still requires 32-bit cross compilation libraries.
RUN echo "Installing necessary system packages to support steam CLI installation..." && \
    apt-get update && \
    apt-get install -y bash expect htop tmux lib32gcc1 pigz telnet wget && \
    rm -rf /var/lib/apt/lists/*

# Create a non-privileged user to run with.
RUN useradd -u 7999 -d ${SERVER_HOME} zed

RUN echo "Create server directories..." && \
    mkdir -p ${SERVER_HOME} && \
    mkdir -p ${SERVER_INSTALL_DIR} && \
    mkdir -p ${SERVER_INSTALL_DIR}/Mods && \
    mkdir -p ${SERVER_DATA_DIR} && \
    chown -R zed ${SERVER_HOME}

USER zed

WORKDIR ${SERVER_HOME}

COPY scripts/steamcmd-7dtd.script ${SERVER_HOME}/

# This is most likely going to be the largest layer created; all the game files for the
# dedicated server.
RUN echo "Downloading and installing steamcmd..." && \
    wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz && \
    tar -zxvf steamcmd_linux.tar.gz

RUN echo "Downloading and installing 7dtd server with steamcmd..." && \
    ${SERVER_HOME}/steamcmd.sh +runscript steamcmd-7dtd.script

# Install custom startserver script.
COPY --chown=zed:root scripts/startserver-1.sh ${SERVER_INSTALL_DIR}/

# Mods and mods related tasks.
COPY --chown=zed:root xpath_mods/ ${SERVER_INSTALL_DIR}/Mods/
COPY --chown=zed:root server_fixes_v19_22_32/ ${SERVER_INSTALL_DIR}/Mods/

# Configuration.
COPY --chown=zed:root config/serverconfig.xml ${SERVER_DATA_DIR}/

# Default web UI control panel port.
EXPOSE 8080

# Default telnet administrative port.
EXPOSE 8081

# Default webserver for allocs mod port.
EXPOSE 8082

# Default game port.
EXPOSE 26900

COPY scripts/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
