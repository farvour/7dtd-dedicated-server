FROM alpine/git:v2.26.2 AS git_modlet_cloner
LABEL stage=intermediate

RUN echo "Clone all Modlets into sourced location for final image COPY command..." && \
    cd /tmp && \
    mkdir output && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/claymore-stainless-steel-returns.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-10k-stacks.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-backpack.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-concrete-spikes.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-easier-demolishers.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-easier-gamestages.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-faster-smelting.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-log-spikes.git && \
    git clone --depth 1 https://gitlab.com/7dtd/modlets/krampusmod-steel-bars.git && \
    cp -rpv claymore-stainless-steel-returns/Claymore_Stainless_Steel_Returns output/ && \
    cp -rpv krampusmod-10k-stacks/KrampusMod_10K_Stacks output/ && \
    cp -rpv krampusmod-backpack/KrampusMod_Backpack output/ && \
    cp -rpv krampusmod-concrete-spikes/KrampusMod_Concrete_Spikes output/ && \
    cp -rpv krampusmod-easier-demolishers/KrampusMod_Easier_Demolishers output/ && \
    cp -rpv krampusmod-easier-gamestages/KrampusMod_Easier_Gamestages output/ && \
    cp -rpv krampusmod-faster-smelting/KrampusMod_Faster_Smelting output/ && \
    cp -rpv krampusmod-log-spikes/KrampusMod_Log_Spikes output/ && \
    cp -rpv krampusmod-steel-bars/KrampusMod_Steel_Bars output/ && \
    ls -la /tmp && \
    echo "Done!"

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

# Install custom startserver script.
COPY --chown=z:root scripts/startserver-1.sh ${SERVER_INSTALL_DIR}/

# Custom prefabs.
COPY --chown=z:root custom_prefabs/ ${SERVER_INSTALL_DIR}/Data/Prefabs/

# Install custom configuration.
COPY --chown=z:root config/serverconfig.xml ${SERVER_INSTALL_DIR}/

# Mods and mods related tasks.
# COPY --chown=z:root server_fixes_v19_22_32/ ${SERVER_INSTALL_DIR}/Mods/
COPY --chown=z:root mods/BCManager/ ${SERVER_INSTALL_DIR}/Mods/BCManager/
COPY --chown=z:root xpath_mods/ ${SERVER_INSTALL_DIR}/Mods/

# Modlets from repositories.
COPY --from=git_modlet_cloner --chown=z:root /tmp/output/ ${SERVER_INSTALL_DIR}/Mods/

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
