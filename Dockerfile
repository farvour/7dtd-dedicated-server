FROM debian:bullseye
LABEL maintainer="Thomas Farvour <tom@farvour.com>"

ARG DEBIAN_FRONTEND=noninteractive

# Top level directory where everything related to the 7dtd server
# is installed to. Since you can bind-mount data volumes for worlds,
# saves or other things, this doesn't really have to change, but is
# here for clarity and customization in case.

ENV SERVER_HOME=/opt/7dtd
ENV SERVER_INSTALL_DIR=/opt/7dtd/7dtd-dedicated-server
ENV SERVER_DATA_DIR=/var/opt/7dtd/data

# Use root user to install system packages and setup users.
USER root

# Steam still requires 32-bit cross compilation libraries.
RUN echo "=== installing necessary system packages to support steam CLI installation..." \
    && apt-get update \
    && apt-get -yy --no-install-recommends install \
    bash ca-certificates curl dumb-init expect git gosu htop \
    lib32gcc-s1 net-tools netcat pigz rsync telnet tmux unzip \
    vim wget \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

# Non-privileged user.
ENV PROC_UID 7999
ENV PROC_USER z
ENV PROC_GROUP nogroup

RUN echo "=== create a non-privileged user to run with." \
    && useradd -u ${PROC_UID} -d ${SERVER_HOME} -g ${PROC_GROUP} ${PROC_USER}

RUN echo "=== create server directories..." \
    && mkdir -p ${SERVER_HOME} \
    && mkdir -p ${SERVER_INSTALL_DIR} \
    && mkdir -p ${SERVER_INSTALL_DIR}/Mods \
    && mkdir -p ${SERVER_DATA_DIR} \
    && mkdir -p ${SERVER_HOME}/Steam \
    && chown -R ${PROC_USER}:${PROC_GROUP} ${SERVER_HOME}

USER ${PROC_USER}

WORKDIR ${SERVER_HOME}

RUN echo "=== downloading and installing steamcmd..." \
    && cd Steam \
    && wget https://media.steampowered.com/installer/steamcmd_linux.tar.gz \
    && tar -zxvf steamcmd_linux.tar.gz \
    && chown -R ${PROC_USER}:${PROC_GROUP} . \
    && cd -

# This is most likely going to be the largest layer created; all the game
# files for the dedicated server. NOTE: It is a good idea to do as much as
# possible _beyond_ this point to avoid Docker having to re-create it.
RUN echo "=== downloading and installing 7dtd server with steamcmd..." \
    && ${SERVER_HOME}/Steam/steamcmd.sh \
    +force_install_dir ${SERVER_INSTALL_DIR} \
    +login anonymous \
    +app_update 294420 -beta latest_experimental \
    +quit

# Additional system packages for everything not for the Steam installation.
# This includes Python, pipenv, and the correct Pipfile lock deployed to the
# system installation of Python 3.

USER root

ENV ASDF_DIR /opt/asdf-vm
ENV ASDF_DATA_DIR ${ASDF_DIR}
ENV ASDF_BRANCH v0.12.0

RUN echo "=== Cloning asdf-vm ${ASDF_BRANCH} into ${ASDF_DIR}" \
    && git clone https://github.com/asdf-vm/asdf.git ${ASDF_DIR} --branch ${ASDF_BRANCH}

RUN cat >/etc/profile.d/asdf.sh <<EOF
export ASDF_DIR=$ASDF_DIR
export ASDF_DATA_DIR=$ASDF_DATA_DIR

. ${ASDF_DIR}/asdf.sh
EOF

ENV PYTHON_VERSION 3.11.4

RUN echo "=== Installing packages to support Python installation, run-time and entrypoint of server" \
    && apt-get update \
    && apt-get -yy --no-install-recommends install \
    build-essential \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libreadline-dev \
    libssl-dev \
    libsqlite3-dev \
    wget \
    zlib1g-dev \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

RUN echo "=== Installing Python ${PYTHON_VERSION} via asdf-vm" \
    && . /etc/profile.d/asdf.sh \
    && asdf plugin add python \
    && asdf install python ${PYTHON_VERSION} \
    && asdf global python ${PYTHON_VERSION}

# Sets the proper locale variables for the environment.
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

ENV PIPENV_VENV_IN_PROJECT=1

RUN echo "=== Ensure pipenv is installed" \
    && . /etc/profile.d/asdf.sh \
    && python -V \
    && pip install pipenv

COPY Pipfile ${SERVER_HOME}
COPY Pipfile.lock ${SERVER_HOME}

RUN echo "=== Install Pipfile requirements" \
    && . /etc/profile.d/asdf.sh \
    && python -V \
    && pipenv install --deploy

USER ${PROC_USER}

# Install the backup2l script for automatic backup assistance.
# You can simply run this script in the container and backup the mounted
# volume to a destination available on the host.

# docker run --rm --entrypoint /bin/bash -v 7dtd-dedicated-server_7dtd-data:/app/7dtd/data/Saves -v /mnt/backup:/app/7dtd/backups 7dtd-dedicated-server_7dtd-server:latest /app/7dtd/backup2l/backup2l -c /app/7dtd/backup2l/backup2l.conf -b

RUN echo "=== Install the backup2l tool and config" \
    && git clone --single-branch --branch master https://github.com/gkiefer/backup2l.git \
    && if [ ! -d ${SERVER_HOME}/backups ]; then mkdir -p ${SERVER_HOME}/backups; fi

COPY --chown=${PROC_USER}:${PROC_GROUP} config/backup2l.conf ${SERVER_HOME}/backup2l/backup2l.conf

# Install custom startserver script (adds support for generator tool below, etc).
COPY --chown=${PROC_USER}:${PROC_GROUP} scripts/startserver-1.sh ${SERVER_INSTALL_DIR}/

# Custom prefabs.
COPY --chown=${PROC_USER}:${PROC_GROUP} custom_prefabs/ ${SERVER_INSTALL_DIR}/Data/Prefabs/

# Mods and mods related tasks.
COPY --chown=${PROC_USER}:${PROC_GROUP} xpath_mods_src/ ${SERVER_INSTALL_DIR}/xpath_mods_src/
COPY --chown=${PROC_USER}:${PROC_GROUP} xpath_mods/ ${SERVER_INSTALL_DIR}/Mods/

# Install the server configuration generator tool.
COPY --chown=${PROC_USER}:${PROC_GROUP} scripts/generate_server_config.py ${SERVER_HOME}/

# Install configuration base value input files.
COPY --chown=${PROC_USER}:${PROC_GROUP} config/serverconfig.xml.values.in.yaml ${SERVER_HOME}/
COPY --chown=${PROC_USER}:${PROC_GROUP} config/serveradmin.xml.values.in.yaml ${SERVER_HOME}/

# Switch back to root user to allow entrypoint to drop privileges.
USER root

# Default web UI panel port.
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

# Set entrypoint and default command.
ENTRYPOINT ["/usr/bin/dumb-init", "--rewrite", "15:2", "--", "/entrypoint.sh"]
CMD ["./startserver-1.sh", "-configfile=serverconfig.xml"]
