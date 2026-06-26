# SJTU VPN SOCKS5 Proxy

## Intro

This project establishes an SJTU VPN connection inside a Docker container and exposes a local SOCKS5 proxy on the host. It is intended for tools such as SSH that need to reach SJTU-only addresses without making the macOS host join the VPN directly.

The default student profile forces the VPN server to IPv4 through `stuv4.vpn.sjtu.edu.cn`.

## Security model

The SOCKS5 proxy has no username or password. By default, Docker only publishes it to `127.0.0.1:1080` on the host:

```yaml
ports:
  - "127.0.0.1:${HOST_SOCKS_PORT:-1080}:1080/tcp"
```

Do not expose this port on `0.0.0.0` unless you fully understand the risk.

## Usage

1. Create your local environment file:

    ```bash
    cp .env.example .env
    ```

2. Edit `.env` and fill in your jAccount credentials:

    ```env
    JACCOUNT=your_jaccount
    JPASSWORD=your_jaccount_password
    ```

3. Start the container:

    ```bash
    docker compose up -d --build
    docker logs -f sjtu-vpn-socks
    ```

4. Use the SOCKS5 proxy directly from SSH:

    ```bash
    ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' user@your-internal-server
    ```

    Or add a host entry to `~/.ssh/config`:

    ```sshconfig
    Host sjtu-server
      HostName your-internal-server
      User your-user
      Port 22
      ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
    ```

    Then connect with:

    ```bash
    ssh sjtu-server
    ```

## Configuration

The default `.env.example` is for the SJTU student IPv4 VPN endpoint:

```env
VPN_SERVER=stuv4.vpn.sjtu.edu.cn
VPN_RIGHTID=@stu.vpn.sjtu.edu.cn
HOST_SOCKS_PORT=1080
```

If you need a different SJTU VPN profile, override `VPN_SERVER` and `VPN_RIGHTID` in `.env`.

## Troubleshooting

Check whether the VPN is up:

```bash
docker logs -f sjtu-vpn-socks
```

Check whether the SOCKS5 port is listening on macOS:

```bash
nc -vz 127.0.0.1 1080
```

If Docker Desktop on macOS cannot provide `/dev/net/tun`, run this project on a Linux machine or VM instead.
