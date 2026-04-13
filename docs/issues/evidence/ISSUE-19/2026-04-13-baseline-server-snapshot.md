# ISSUE-19 Evidence: Baseline Server Snapshot (2026-04-13)

<!-- cspell:ignore estab timewait entr -->

## Context

Initial server snapshot collected to establish a baseline before deeper UDP uptime investigation.

## Command

```bash
ssh demotracker 'set -e; echo "=== now ==="; date -u; echo "=== uptime ==="; uptime; echo "=== memory ==="; free -h; echo "=== disk ==="; df -h; echo "=== udp sockets summary ==="; ss -u -s; echo "=== docker services ==="; cd /opt/torrust && docker compose ps'
```

## Output

```text
=== now ===
Mon Apr 13 14:22:10 UTC 2026
=== uptime ===
 14:22:10 up 8 days, 12:21,  2 users,  load average: 6.87, 7.18, 7.11
=== memory ===
               total        used        free      shared  buff/cache   available
Mem:            15Gi       2.5Gi       7.2Gi       5.3Mi       5.8Gi        12Gi
Swap:             0B          0B          0B
=== disk ===
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           1.6G  1.4M  1.6G   1% /run
efivarfs        256K   39K  213K  16% /sys/firmware/efi/efivars
/dev/sda1       150G  9.5G  135G   7% /
tmpfs           7.7G     0  7.7G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda15      253M  146K  252M   1% /boot/efi
/dev/sdb         49G  2.0G   45G   5% /opt/torrust/storage
tmpfs           1.6G   12K  1.6G   1% /run/user/1000
=== udp sockets summary ===
Total: 206
TCP:   14462 (estab 4, closed 14445, orphaned 8077, timewait 9)

Transport Total     IP        IPv6
RAW       1         0         1
UDP       9         6         3
TCP       17        14        3
INET      27        20        7
FRAG      0         0         0

Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
=== docker services ===
NAME         IMAGE                     COMMAND                  SERVICE      CREATED       STATUS                 PORTS
caddy        caddy:2.10.2              "caddy run --config …"   caddy        3 hours ago   Up 2 hours (healthy)   0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp, 0.0.0.0:443->443/udp, :::443->443/udp, 2019/tcp
grafana      grafana/grafana:12.4.2    "/run.sh"                grafana      2 hours ago   Up 2 hours (healthy)   3000/tcp
mysql        mysql:8.4                 "docker-entrypoint.s…"   mysql        3 hours ago   Up 3 hours (healthy)   3306/tcp, 33060/tcp
prometheus   prom/prometheus:v3.5.1    "/bin/prometheus --c…"   prometheus   3 hours ago   Up 2 hours (healthy)   127.0.0.1:9090->9090/tcp
tracker      torrust/tracker:develop   "/usr/local/bin/entr…"   tracker      3 hours ago   Up 3 hours (healthy)   1212/tcp, 0.0.0.0:6868->6868/udp, :::6868->6868/udp, 1313/tcp, 7070/tcp, 0.0.0.0:6969->6969/udp, :::6969->6969/udp
```

## Notes

- This is raw evidence capture only (not a post-mortem).
- Current signal to investigate next: high load average with relatively low memory pressure.
