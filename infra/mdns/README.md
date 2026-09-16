# Arena API LAN discovery

This Linux Docker host-network service advertises DNS-SD type
`_arena-api._tcp.local.`, instance `Arena API (<host IPv4>)`, and hostname
`arena-api-<IPv4 with hyphens>.local.`. Zeroconf may rename a conflicting service instance.
Only the selected IPv4 address is published and used for multicast.
The address-qualified hostname keeps separate development hosts from publishing
conflicting addresses for a shared hostname.

| Variable | Default | Meaning |
| --- | --- | --- |
| `BACKEND_PORT` | `8080` | Backend's published host port; also used by Compose's backend port mapping. |
| `MDNS_ADDRESS` | automatic | Optional IPv4 assigned to the host LAN interface. |

Automatic selection uses the lowest-metric active IPv4 default route in
`/proc/net/route` and that interface's primary IPv4. It rejects bridge interfaces
(including Docker bridges) rather than advertising container network addresses.
If a VPN owns the default route, policy routing is in use, or the host has
multiple LANs, set `MDNS_ADDRESS` explicitly to the LAN IPv4 reachable by the phone.
Loopback, wildcard, multicast, reserved, and link-local addresses are rejected.
An override must be assigned to a local interface; Zeroconf binds to it.
Restart/recreate the service after a host address change.

TXT records are `scheme=http`, `path=/api`, and `apiVersion=1`. Clients construct
the origin as `http://<discovered IPv4>:<discovered port>` and append `/api` when
building API request URLs. Do not treat `/api` as part of the origin or append
it twice. This does not configure HTTPS tunnels, TLS, or authentication issuers.

The phone and Linux host must be on the same multicast-capable LAN. Allow mDNS
UDP 5353 and the backend TCP port through the host firewall. Wi-Fi client
isolation or multicast filtering can prevent discovery. No Avahi daemon, D-Bus,
privileged mode, host volumes, or additional published ports are needed.

## Build and isolated tests (no LAN advertisement)

From the repository root:

```sh
docker compose build mdns
docker run --rm --network none --entrypoint python \
  -v "$PWD/infra/mdns/test_advertise.py:/app/test_advertise.py:ro" \
  arena-assessment-mdns -m unittest -v test_advertise
```

Start with `docker compose up --build --wait` or start just the advertiser using
`docker compose up -d mdns` (this also starts required dependencies).
Set `BACKEND_PORT` and `MDNS_ADDRESS` consistently in the Compose environment.

The healthcheck requires a marker written only after successful registration
and a live advertiser PID. It reports registration readiness, not end-to-end
LAN reachability or ongoing backend health. Compose waits for a healthy backend
on startup. SIGTERM/SIGINT remove readiness, unregister the service, and close
Zeroconf; failures exit nonzero and Compose restarts the process. The only runtime
file is `/tmp/arena-mdns-ready` (keep `/tmp` writable if adding a read-only root).
