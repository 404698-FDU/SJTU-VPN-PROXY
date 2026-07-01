#!/usr/bin/env bash
set -euo pipefail

: "${JACCOUNT:?need JACCOUNT}"
: "${JPASSWORD:?need JPASSWORD}"

SOCKS_ADDR="${SOCKS_ADDR:-0.0.0.0}"
SOCKS_PORT="${SOCKS_PORT:-1080}"

# IPv4 only: use stuv4 for the student VPN server by default.
VPN_SERVER="${VPN_SERVER:-stuv4.vpn.sjtu.edu.cn}"
# Keep rightid as @stu.vpn.sjtu.edu.cn for the student profile.
VPN_RIGHTID="${VPN_RIGHTID:-@stu.vpn.sjtu.edu.cn}"

# Import system trusted CA certificates.
rm -f /etc/ipsec.d/cacerts/* || true
ln -s /etc/ssl/certs/* /etc/ipsec.d/cacerts/ || true

# Disable certificate revocation checks; the SJTU Linux guide commonly needs this
# in container/minimal environments where CRL fetching is unreliable.
mkdir -p /etc/strongswan.d/charon
cat >/etc/strongswan.d/charon/revocation.conf <<EOF_CONF
revocation {
  load = no
}
EOF_CONF

cat >/etc/ipsec.conf <<EOF_CONF
config setup

conn "sjtu-student"
    keyexchange=ikev2
    left=%config
    leftsourceip=%config4
    leftauth=eap-peap
    right=${VPN_SERVER}
    rightid=${VPN_RIGHTID}
    rightsendcert=never
    rightsubnet=0.0.0.0/0
    rightauth=pubkey
    eap_identity="${JACCOUNT}"
    auto=add
    aaa_identity="@radius.net.sjtu.edu.cn"
    dpdaction=restart
    dpddelay=20s
    dpdtimeout=120s
    keyingtries=%forever
    closeaction=restart
    reauth=no
    mobike=yes
EOF_CONF

cat >/etc/ipsec.secrets <<EOF_CONF
"${JACCOUNT}" : EAP "${JPASSWORD}"
EOF_CONF

ipsec restart

set +e
ipsec up "sjtu-student"
rc=$?
if [ "$rc" -ne 0 ]; then
  sleep 2
  ipsec up "sjtu-student"
fi
set -e

# strongSwan may install an IPv6 DNS server while this container disables IPv6.
cat >/etc/resolv.conf <<EOF_CONF
nameserver 202.120.2.101
nameserver 202.120.2.100
options timeout:2 attempts:2
EOF_CONF

echo "== VPN status =="
ipsec statusall || true
echo "== Test IPv4 =="
curl -4 -s whatismyip.sjtu.edu.cn || true
echo

echo "== Start SOCKS5 proxy =="
echo "listen ${SOCKS_ADDR}:${SOCKS_PORT}"

exec python3 /socks_proxy.py --host "${SOCKS_ADDR}" --port "${SOCKS_PORT}"
