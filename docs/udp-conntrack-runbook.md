<!-- cspell:ignore Rcvbuf conntrack softirq recvmmsg NoPorts ksoftirqd nproc vmstat mpstat -->

# UDP Conntrack Runbook

Operational guide for detecting, fixing, and explaining UDP packet loss caused
by conntrack saturation or related kernel-side packet-path pressure.

This runbook exists for reuse beyond issue-specific evidence. For the incident
that led to the current tuning, see
[ISSUE-21](issues/ISSUE-21-scale-up-server-for-udp-uptime.md) and the evidence
under `docs/issues/evidence/ISSUE-21/`.

## When To Use This Runbook

Use this runbook when one or more of these symptoms appear:

- newTrackon or other external probes show intermittent UDP timeouts
- UDP uptime drops while HTTP stays healthy
- UDP request volume is high and Docker DNAT is in the packet path
- `nf_conntrack` may be full or close to full
- Host load looks odd relative to per-CPU usage and packet drops are suspected

## How To Detect The Problem

### External Symptoms

Common user-visible symptoms:

- External UDP probes alternate between working and timing out
- Failures self-recover without a deploy or restart
- HTTP tracker remains mostly healthy while UDP uptime degrades
- Rolling uptime remains low for hours even after recent successful probes

### Host Checks

Run this on the live host:

```bash
ssh demotracker '
  echo "=== conntrack counts ===" &&
  sudo sysctl net.netfilter.nf_conntrack_max net.netfilter.nf_conntrack_count &&
  echo "=== UDP timeouts ===" &&
  sudo sysctl net.netfilter.nf_conntrack_udp_timeout \
              net.netfilter.nf_conntrack_udp_timeout_stream &&
  echo "=== dmesg table full ===" &&
  sudo dmesg -T | grep -i "nf_conntrack: table full" | tail -10 &&
  echo "(no output = no table-full events)" &&
  echo "=== UDP receive errors ===" &&
  cat /proc/net/snmp | grep -E "^Udp:" |
    awk "NR==1{for(i=1;i<=NF;i++) h[i]=\$i} NR==2{for(i=1;i<=NF;i++) print h[i]\": \"\$i}" |
    grep -E "RcvbufErrors|InErrors|NoPorts" &&
  echo "=== UDP6 receive errors ===" &&
  cat /proc/net/snmp6 | grep -E "Udp6RcvbufErrors|Udp6InErrors|Udp6NoPorts"
'
```

Interpret the output like this:

- `nf_conntrack_count == nf_conntrack_max`: immediate problem; table is full
- `dmesg` contains `nf_conntrack: table full, dropping packet`: confirmed drops
- `UdpRcvbufErrors > 0` or `Udp6RcvbufErrors > 0`: receive-buffer drops exist
- `UdpNoPorts` or `Udp6NoPorts`: usually benign; probes to closed ports, not the tracker itself

### Optional Load Distribution Check

Use this when load average looks high but per-process CPU usage does not explain
it clearly:

```bash
ssh demotracker '
  uptime &&
  nproc &&
  mpstat -P ALL 1 1 2>/dev/null || echo "mpstat not available" &&
  ps -eo pid,comm,%cpu,%mem,stat --sort=-%cpu | head -15 &&
  vmstat 1 3
'
```

Interpretation:

- high `%soft` on one CPU means kernel packet handling is concentrated there
- this points to softirq/RX steering imbalance, not necessarily tracker code problems
- this is a separate bottleneck from conntrack table saturation

## How To Fix It

### Immediate Live Fix

Apply the kernel tuning live:

```bash
ssh demotracker '
  sudo sysctl -w net.netfilter.nf_conntrack_max=1048576 &&
  sudo sysctl -w net.netfilter.nf_conntrack_udp_timeout=10 &&
  sudo sysctl -w net.netfilter.nf_conntrack_udp_timeout_stream=15
'
```

### Persist The Fix In This Repository

The persistent configuration lives in:

- `server/etc/sysctl.d/99-conntrack.conf`
- `server/etc/modules-load.d/conntrack.conf`

Why both files matter:

- `99-conntrack.conf` stores the kernel parameter values
- `conntrack.conf` preloads the `nf_conntrack` module at boot
- without preloading, the `net.netfilter.*` keys may not exist yet when systemd applies sysctl files, so the values can be skipped after reboot

Current tuned values used by this repository:

| Key                                             | Value     |
| ----------------------------------------------- | --------- |
| `net.netfilter.nf_conntrack_max`                | `1048576` |
| `net.netfilter.nf_conntrack_udp_timeout`        | `10`      |
| `net.netfilter.nf_conntrack_udp_timeout_stream` | `15`      |

### Validate After The Change

Re-run the detection command above and confirm all of these:

- `nf_conntrack_count` is well below `nf_conntrack_max`
- no fresh `table full` messages appear in `dmesg`
- `UdpRcvbufErrors` and `Udp6RcvbufErrors` are stable or zero
- external UDP probes recover and remain healthy for multiple hours or days

## Why This Works

### Packet Path

For the deployed tracker, the UDP receive path is approximately:

```text
NIC -> kernel RX interrupt -> softirq/ksoftirqd -> conntrack + Docker DNAT -> socket buffer -> tracker recv loop -> spawned async task
```

The important point is that conntrack lookup and DNAT happen in the kernel
before the tracker reads the packet from the socket.

### Failure Mechanism

With Docker in the packet path, each UDP packet can create or refresh a
conntrack entry.

If all of these are true at the same time:

- request rate is high
- `nf_conntrack_max` is too small
- UDP entry timeouts are too long

then the steady-state number of tracked UDP flows grows until the table is full.
Once full, the kernel drops new packets before the tracker can read them.

### Why Increasing `nf_conntrack_max` Helps

Increasing `nf_conntrack_max` raises the ceiling for concurrent tracked flows,
reducing the chance that bursts or sustained load fill the table.

### Why Reducing UDP Timeouts Helps

Reducing `nf_conntrack_udp_timeout` and
`nf_conntrack_udp_timeout_stream` shortens how long old UDP entries stay in the
table.

That reduces steady-state occupancy, which is often more important than raw CPU
capacity for this failure mode.

### Why The Tracker Code Is Not The Root Cause

The tracker's UDP loop reads packets after the kernel has already:

- handled the RX interrupt/softirq work
- performed conntrack lookup
- applied Docker NAT rules
- copied the packet into the socket receive buffer

If packets are being dropped because the conntrack table is full, the tracker
never sees them.

## Separate Future Tuning: RPS/RFS

RPS and RFS are not part of the current deployed fix. They address a different
bottleneck: one CPU being saturated by kernel softirq work while other CPUs sit
idle. They solve a different problem from conntrack table saturation.

### How To Detect The Need For RPS/RFS

Run the load distribution check:

```bash
ssh demotracker '
  uptime &&
  nproc &&
  mpstat -P ALL 1 1 &&
  vmstat 1 3
'
```

Signals that RPS/RFS may help:

- one CPU shows `%soft` near or above 80–90% while other CPUs have significant
  `%idle`
- `vmstat` shows very high interrupt counts (`in` column) and many context
  switches (`cs` column)
- `ps` shows `ksoftirqd/<N>` for a single CPU near the top of CPU consumers

This pattern was first observed on this server on 2026-04-27:

```text
CPU2:  %usr=4.76  %sys=4.76  %soft=80.95  %idle=9.52
```

All other CPUs were at approximately 44% idle at the same time.

### Why It Happens

The Hetzner VM's virtio-net NIC has a single RX queue. Linux assigns that
queue's hardware interrupt to one CPU. All softirq processing for every incoming
packet — UDP and TCP — flows through that one core.

The softirq work includes:

- NIC DMA and descriptor processing
- IP and UDP checksums
- conntrack lookup and Docker DNAT
- socket demux and receive-buffer copy

Until one of the RX-steering features is enabled, the kernel has no way to
distribute this work.

### How To Estimate Whether This Is A Real Bottleneck

At current peak UDP traffic of ~750 req/s and HTTP of ~2000 req/s, the softirq
CPU (CPU2) was at about 81%. Saturation would occur if that figure approaches
100% consistently.

A rough rule of thumb: if total req/s grows by roughly 2.5× from the 2026-04-27
baseline (~2750 req/s combined) without any RPS/RFS tuning, CPU2 may saturate
and become the next source of packet loss.

### How To Fix It — RPS

RPS tells the kernel to re-queue softirq processing for each packet onto a
different CPU, chosen by hashing the packet's 4-tuple (src IP, src port, dst
IP, dst port).

Check the NIC and queue name first:

```bash
ssh demotracker 'ls /sys/class/net/'
ssh demotracker 'ls /sys/class/net/eth0/queues/'
```

Enable RPS across all 8 CPUs:

```bash
ssh demotracker 'echo ff | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus'
```

The value `ff` is a bitmask: `0xff` = all 8 CPUs. Adjust for the actual CPU
count if the server is resized.

### How To Fix It — RFS

RFS extends RPS by tracking which CPU most recently ran the application socket
thread and steers softirq toward that CPU. This reduces cache misses when the
kernel hands the packet to userspace.

Enable RFS:

```bash
ssh demotracker '
  sudo sysctl -w net.core.rps_sock_flow_entries=32768 &&
  echo 4096 | sudo tee /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
'
```

### Making RPS/RFS Persistent

The `/sys/class/net/...` paths do not survive reboot. To persist them, add a
`systemd` service or a `@reboot` cron entry, and record the kernel parameter in
`/etc/sysctl.d/`.

Example cron entry (`/etc/cron.d/rps`):

```text
@reboot root echo ff > /sys/class/net/eth0/queues/rx-0/rps_cpus && echo 4096 > /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
```

If this is deployed permanently, add the config to:

- `server/etc/sysctl.d/` for the `net.core.rps_sock_flow_entries` setting
- `server/etc/cron.d/` for the sysfs writes

### Validate After Enabling

Re-run `mpstat -P ALL 1 5` and confirm that:

- `%soft` is spread across multiple CPUs instead of concentrated on one
- the formerly saturated CPU drops below 70–80%
- external UDP uptime remains stable or improves

### Why RPS/RFS Does Not Break Conntrack

RPS reorders which CPU handles softirq, but does not bypass conntrack or DNAT.
Each packet still goes through the full kernel stack; it just does so on a
different CPU. The conntrack settings from `99-conntrack.conf` remain in effect
independently.

### Why This Is Separate From The Conntrack Fix

Conntrack overflow causes packet **drops** — the kernel silently discards the
packet before it ever enters a socket buffer. RPS/RFS addresses CPU **hotspot**
— one core being too busy to process incoming packets fast enough. Both can
cause UDP timeouts, but the diagnostic signals are different and the fixes do
not overlap.

## Reference Values From The 2026-04-27 Verification

Recorded before merging PR #22:

- peak UDP tracker traffic observed over the prior 7 days: about `750 req/s`
- peak HTTP tracker traffic observed over the prior 7 days: about `2000 req/s`
- `nf_conntrack_count`: `341652`
- `nf_conntrack_max`: `1048576`
- utilization: `32.59%`
- `UdpRcvbufErrors`: `0`
- `Udp6RcvbufErrors`: `56` cumulative since boot, not material at observed load

## Related Files

- [docs/infrastructure.md](infrastructure.md)
- [docs/infrastructure-resize-history.md](infrastructure-resize-history.md)
- [server/etc/sysctl.d/99-conntrack.conf](../server/etc/sysctl.d/99-conntrack.conf)
- [server/etc/modules-load.d/conntrack.conf](../server/etc/modules-load.d/conntrack.conf)
- [docs/issues/ISSUE-21-scale-up-server-for-udp-uptime.md](issues/ISSUE-21-scale-up-server-for-udp-uptime.md)
