FROM ubuntu/bionic

# Top level directory where everything related to the 7dtd server is installed to.
# Since you can bind-mount data volumes for worlds, saves or other things, this
# doesn't really have to change, but is here for clarity and customization in case.
ARG SERVER_HOME=/zed

# Steam still requires 32-bit cross compilation libraries.
RUN echo "Installing necessary system packages to support steam CLI installation..." && \
    apt-get update && \
    apt-get install -y htop lib32gcc1 pigz wget

RUN echo "Create server home directory..." && \
    mkdir -p ${SERVER_HOME}

# Create a non-privileged user to run with.
RUN useradd -u 7999 -d ${SERVER_HOME} zed

USER zed

RUN echo "Downloading and installing 7dtd server with steamcmd..." && \
    wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz && \
    tar -zxvf steamcmd_linux.tar.gz

# Default telnet administrative port.
EXPOSE 8081

# Default webserver for allocs mod port.
EXPOSE 8082

# Default game port.
EXPOSE 26900
