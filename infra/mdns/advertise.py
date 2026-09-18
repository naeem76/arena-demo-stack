"""Advertise the host-published Arena API on one Linux LAN interface."""

import fcntl
import ipaddress
import logging
import os
from pathlib import Path
import signal
import socket
import struct
import sys
import threading
from collections.abc import Mapping

from zeroconf import IPVersion, ServiceInfo, Zeroconf

SERVICE_TYPE = "_arena-api._tcp.local."
READY_FILE = Path("/tmp/arena-mdns-ready")


def default_address() -> str:
    routes = []
    for line in Path("/proc/net/route").read_text().splitlines()[1:]:
        fields = line.split()
        if fields[1] == "00000000" and int(fields[3], 16) & 1:
            routes.append((int(fields[6]), fields[0]))
    if not routes:
        raise ValueError("No IPv4 default route; set MDNS_ADDRESS to the host LAN IPv4")
    _, interface = min(routes)
    if interface.startswith(("docker", "br-", "veth")) or Path(
        f"/sys/class/net/{interface}/bridge"
    ).exists():
        raise ValueError("Default route uses a bridge; set MDNS_ADDRESS to the host LAN IPv4")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        request = struct.pack("256s", interface.encode())
        response = fcntl.ioctl(sock.fileno(), 0x8915, request)  # SIOCGIFADDR
    return socket.inet_ntoa(response[20:24])


def configuration(env: Mapping[str, str]) -> tuple[str, int]:
    try:
        port = int(env.get("BACKEND_PORT", "18080"))
        if not 1 <= port <= 65535:
            raise ValueError
    except ValueError as exc:
        raise ValueError("BACKEND_PORT must be an integer between 1 and 65535") from exc
    raw_address = env.get("MDNS_ADDRESS") or default_address()
    try:
        address = ipaddress.IPv4Address(raw_address)
    except ipaddress.AddressValueError as exc:
        raise ValueError("MDNS_ADDRESS must be a host LAN IPv4 address") from exc
    if (
        address.is_loopback
        or address.is_unspecified
        or address.is_multicast
        or address.is_reserved
        or address.is_link_local
    ):
        raise ValueError("MDNS_ADDRESS must be a unicast LAN IPv4, not loopback or wildcard")
    return str(address), port


def advertise(address: str, port: int, stop: threading.Event) -> None:
    READY_FILE.unlink(missing_ok=True)
    info = ServiceInfo(
        SERVICE_TYPE,
        f"Arena API ({address}).{SERVICE_TYPE}",
        addresses=[socket.inet_aton(address)],
        port=port,
        properties={"scheme": "http", "path": "/api", "apiVersion": "1"},
        server=f"arena-api-{address.replace('.', '-')}.local.",
    )
    zeroconf = Zeroconf(interfaces=[address], ip_version=IPVersion.V4Only)
    registered = False
    try:
        zeroconf.register_service(info, allow_name_change=True)
        registered = True
        READY_FILE.write_text(str(os.getpid()))
        logging.info("Registered %s: http://%s:%s (path=/api)", info.name, address, port)
        stop.wait()
    finally:
        READY_FILE.unlink(missing_ok=True)
        try:
            if registered:
                zeroconf.unregister_service(info)
        finally:
            zeroconf.close()


def healthy() -> bool:
    try:
        pid = int(READY_FILE.read_text())
        if pid <= 0:
            return False
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def main() -> int:
    if sys.argv[1:] == ["--healthcheck"]:
        return 0 if healthy() else 1
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    READY_FILE.unlink(missing_ok=True)
    stop = threading.Event()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, lambda *_: stop.set())
    try:
        address, port = configuration(os.environ)
        advertise(address, port, stop)
    except Exception:
        logging.exception("mDNS advertiser failed; check BACKEND_PORT and MDNS_ADDRESS")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
