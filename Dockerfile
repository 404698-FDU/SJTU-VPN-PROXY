FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    strongswan curl \
    libstrongswan-extra-plugins libcharon-extra-plugins \
    libcharon-extauth-plugins libstrongswan-standard-plugins \
    ca-certificates iproute2 iputils-ping \
    shadowsocks-libev \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
