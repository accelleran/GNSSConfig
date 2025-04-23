FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install dependencies
RUN apt update && apt install -y \
    gcc make cmake libnl-3-dev libnl-genl-3-dev \
    scons python3-dev python3-setuptools \
    libncurses-dev python3-tk python3-pip \
    asciidoctor python3-cairo gpsd-tools \
    git curl

# Install Python packages
RUN pip3 install matplotlib 

# Clone and build gpsd
WORKDIR /opt
RUN git clone https://gitlab.com/gpsd/gpsd.git && \
    cd gpsd && \
#    scons clean && \
    scons python=true && \
    scons install

# Add ubxtool to PATH
ENV PATH="/usr/local/bin:$PATH"
ENV PYTHONPATH="/usr/local/lib/python3.10/dist-packages"

# Create logging directory
RUN mkdir -p /var/log

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Start container with privileged access
ENTRYPOINT ["/entrypoint.sh"]

