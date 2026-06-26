FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    strongswan curl python3 \
    libstrongswan-extra-plugins libcharon-extra-plugins \
    libcharon-extauth-plugins libstrongswan-standard-plugins \
    ca-certificates iproute2 iputils-ping \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY socks_proxy.py /socks_proxy.py
RUN chmod +x /entrypoint.sh /socks_proxy.py

ENTRYPOINT ["/entrypoint.sh"]
