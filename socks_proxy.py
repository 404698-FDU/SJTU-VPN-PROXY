#!/usr/bin/env python3
import argparse
import select
import socket
import socketserver
import struct


SOCKS_VERSION = 5


def recv_exact(sock, size):
    chunks = []
    remaining = size
    while remaining:
        data = sock.recv(remaining)
        if not data:
            raise ConnectionError("unexpected EOF")
        chunks.append(data)
        remaining -= len(data)
    return b"".join(chunks)


def send_reply(sock, code):
    # Bind address is unused by OpenSSH; return 0.0.0.0:0.
    sock.sendall(bytes([SOCKS_VERSION, code, 0, 1]) + b"\x00\x00\x00\x00\x00\x00")


class SocksHandler(socketserver.BaseRequestHandler):
    timeout = 30

    def handle(self):
        self.request.settimeout(self.timeout)
        try:
            self.negotiate()
            host, port = self.read_connect_request()
            upstream = socket.create_connection((host, port), timeout=self.timeout)
        except Exception as exc:
            try:
                send_reply(self.request, 1)
            except Exception:
                pass
            print(f"connect failed: {exc}", flush=True)
            return

        with upstream:
            send_reply(self.request, 0)
            print(f"connected {host}:{port}", flush=True)
            self.relay(self.request, upstream)

    def negotiate(self):
        version, method_count = recv_exact(self.request, 2)
        if version != SOCKS_VERSION:
            raise ValueError("unsupported SOCKS version")
        methods = recv_exact(self.request, method_count)
        if 0 not in methods:
            self.request.sendall(bytes([SOCKS_VERSION, 0xFF]))
            raise ValueError("client did not offer no-auth method")
        self.request.sendall(bytes([SOCKS_VERSION, 0]))

    def read_connect_request(self):
        version, command, _reserved, address_type = recv_exact(self.request, 4)
        if version != SOCKS_VERSION:
            raise ValueError("unsupported SOCKS version")
        if command != 1:
            send_reply(self.request, 7)
            raise ValueError("only CONNECT is supported")

        if address_type == 1:
            host = socket.inet_ntoa(recv_exact(self.request, 4))
        elif address_type == 3:
            length = recv_exact(self.request, 1)[0]
            host = recv_exact(self.request, length).decode("idna")
        elif address_type == 4:
            host = socket.inet_ntop(socket.AF_INET6, recv_exact(self.request, 16))
        else:
            send_reply(self.request, 8)
            raise ValueError("unsupported address type")

        port = struct.unpack("!H", recv_exact(self.request, 2))[0]
        return host, port

    def relay(self, client, upstream):
        client.settimeout(None)
        upstream.settimeout(None)
        sockets = [client, upstream]

        while True:
            readable, _, errored = select.select(sockets, [], sockets)
            if errored:
                return
            for source in readable:
                target = upstream if source is client else client
                data = source.recv(65536)
                if not data:
                    return
                target.sendall(data)


class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description="Small SOCKS5 CONNECT proxy")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=1080)
    args = parser.parse_args()

    with ThreadingTCPServer((args.host, args.port), SocksHandler) as server:
        print(f"SOCKS5 proxy listening on {args.host}:{args.port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
