# SJTU VPN SOCKS5 Proxy

Run the SJTU VPN inside Docker and expose it as a local SOCKS5 proxy on macOS/Linux. This is useful when you only want specific tools, such as SSH, to go through SJTU VPN without letting the whole host join the VPN.

The current default profile targets the SJTU student IPv4 endpoint:

- VPN server: `stuv4.vpn.sjtu.edu.cn`
- rightid: `@stu.vpn.sjtu.edu.cn`
- local SOCKS5 proxy: `127.0.0.1:1080`

## How it Works

The container starts a strongSwan IKEv2 VPN session, then runs a small SOCKS5 proxy inside the same network namespace. Docker publishes only the SOCKS5 port to the host, so host tools can opt in by using `127.0.0.1:1080` as a SOCKS5 proxy.

By default the proxy is bound on the host loopback address only:

```yaml
ports:
  - "127.0.0.1:${HOST_SOCKS_PORT:-1080}:1080/tcp"
```

Do not expose this port on `0.0.0.0` unless you fully understand the security risk.

## Requirements

- Docker or Colima on macOS/Linux
- `/dev/net/tun` available to containers
- A valid SJTU jAccount
- If you also run Clash/FLClash TUN mode: DNS must return the real SJTU VPN server IPs, not fake-ip addresses

On macOS with Colima, one known-good setup is:

```bash
brew install docker docker-compose colima
colima start --cpu 2 --memory 4 --disk 20
```

Check Docker:

```bash
docker info
```

## Configuration

Create your local environment file:

```bash
cp .env.example .env
```

Edit `.env` and fill in your jAccount credentials:

```env
JACCOUNT=your_jaccount
JPASSWORD=your_jaccount_password

VPN_SERVER=stuv4.vpn.sjtu.edu.cn
VPN_RIGHTID=@stu.vpn.sjtu.edu.cn
HOST_SOCKS_PORT=1080
```

`JPASSWORD` is your jAccount password. If your account uses a six-digit password for VPN login, keep it exactly as the six digits.

## Start

Build and start the container:

```bash
docker-compose up -d --build
```

If your Docker installation supports the Compose plugin, this also works:

```bash
docker compose up -d --build
```

Follow logs:

```bash
docker logs -f sjtu-vpn-socks
```

A successful VPN connection should contain lines similar to:

```text
EAP-MS-CHAPv2 succeeded
IKE_SA sjtu-student[1] established
CHILD_SA sjtu-student{1} established
SOCKS5 proxy listening on 0.0.0.0:1080
```

## Use with SSH

Use the SOCKS5 proxy directly:

```bash
ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' user@internal-host
```

Example with a custom port:

```bash
ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' -p 5681 shijunkai@202.120.15.57
```

Or add a host entry to `~/.ssh/config`:

```sshconfig
Host sjtu-server
  HostName 202.120.15.57
  User shijunkai
  Port 5681
  ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
```

Then connect with:

```bash
ssh sjtu-server
```

To test reachability without submitting a password:

```bash
ssh -v \
  -o BatchMode=yes \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o NumberOfPasswordPrompts=0 \
  -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' \
  -p 5681 shijunkai@202.120.15.57
```

If the output includes `Authentications that can continue: publickey,password`, the proxy and VPN path are working. `Permission denied` is expected in this test because no password is submitted.

## Clash / FLClash DNS Pitfall

If Clash/FLClash TUN mode is enabled on the host, a `DIRECT` rule alone may not be enough. The VPN handshake happens from inside Docker, but DNS and routing can still be affected by the host-side TUN stack.

The important rule is: `stuv4.vpn.sjtu.edu.cn` must resolve to real SJTU IP addresses, not Clash fake-ip addresses.

Known bad symptom:

```text
stuv4.vpn.sjtu.edu.cn -> 198.18.x.x
strongSwan stays CONNECTING
IKE_SA is not established
```

Known-good behavior:

```text
stuv4.vpn.sjtu.edu.cn -> 111.186.48.0 or 111.186.54.0
EAP-MS-CHAPv2 succeeded
IKE_SA established
```

For FLClash, switch DNS mode from fake-ip to `redir-host` or any mode that returns real DNS answers for the SJTU VPN domain. After changing DNS mode, recreate the container so strongSwan resolves the VPN server again:

```bash
docker-compose down
docker-compose up -d --build
```

If it still fails, check DNS from both the host and the container:

```bash
nslookup stuv4.vpn.sjtu.edu.cn

docker exec sjtu-vpn-socks getent hosts stuv4.vpn.sjtu.edu.cn
```

## Troubleshooting

Check VPN status:

```bash
docker exec sjtu-vpn-socks ipsec statusall
```

Expected successful status:

```text
Security Associations (1 up, 0 connecting)
sjtu-student[...]: ESTABLISHED
sjtu-student{...}: INSTALLED, TUNNEL
```

Check whether the SOCKS5 port is listening on the host:

```bash
nc -vz 127.0.0.1 1080
```

Check the VPN egress IP from inside the container:

```bash
docker exec sjtu-vpn-socks curl -4 -s whatismyip.sjtu.edu.cn
```

Restart from a clean container after changing `.env` or DNS/VPN settings:

```bash
docker-compose down
docker-compose up -d --build
```

Common failure causes:

- `.env` credentials are wrong or not loaded
- `JPASSWORD` is not the VPN login password expected by SJTU
- Clash/FLClash DNS returns `198.18.x.x` fake-ip results for the VPN server
- Docker/Colima cannot provide `/dev/net/tun`
- Another process already uses the host SOCKS5 port

## Stop

```bash
docker-compose down
```
