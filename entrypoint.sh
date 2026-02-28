#!/usr/bin/env bash
set -euo pipefail

: "${JACCOUNT:?need JACCOUNT}"
: "${JPASSWORD:?need JPASSWORD}"
: "${SS_PASSWORD:?need SS_PASSWORD}"

# Shadowsocks config
SS_METHOD="${SS_METHOD:-aes-256-gcm}"
SS_PORT="${SS_PORT:-8388}"
SS_ADDR="${SS_ADDR:-0.0.0.0}"

# IPv4 only: use stuv4 for the student VPN server (avoid IPv6 server connections)
VPN_SERVER="${VPN_SERVER:-stuv4.vpn.sjtu.edu.cn}"
# Keep rightid as @stu.vpn.sjtu.edu.cn (required by student config)
VPN_RIGHTID="${VPN_RIGHTID:-@stu.vpn.sjtu.edu.cn}"

# Import system trusted CA certificates
rm -f /etc/ipsec.d/cacerts/* || true
ln -s /etc/ssl/certs/* /etc/ipsec.d/cacerts/ || true

# Disable certificate revocation checks: revocation.load=no
mkdir -p /etc/strongswan.d/charon
cat >/etc/strongswan.d/charon/revocation.conf <<EOF_CONF
revocation {
  load = no
}
EOF_CONF

# Write sjtu-student config (guide fields, adjusted to IPv4-only: leftsourceip=%config4, rightsubnet=0.0.0.0/0)
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
EOF_CONF

# Write secrets: note the spaces around the colon
cat >/etc/ipsec.secrets <<EOF_CONF
"${JACCOUNT}" : EAP "${JPASSWORD}"
EOF_CONF

# Start strongSwan
ipsec restart

# Try to establish the tunnel (retry once if the network is slow)
set +e
ipsec up "sjtu-student"
rc=$?
if [ $rc -ne 0 ]; then
  sleep 2
  ipsec up "sjtu-student"
fi
set -e

echo "== VPN status =="
ipsec statusall || true
echo "== Test IPv4 =="
curl -4 -s whatismyip.sjtu.edu.cn || true
echo

echo "== Start Shadowsocks =="
echo "listen ${SS_ADDR}:${SS_PORT}, method ${SS_METHOD}"

# Run ss-server in the foreground so the container lifecycle follows the proxy process
exec ss-server \
  -s "${SS_ADDR}" \
  -p "${SS_PORT}" \
  -k "${SS_PASSWORD}" \
  -m "${SS_METHOD}" \
  -u
