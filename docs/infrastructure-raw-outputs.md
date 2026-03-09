# Infrastructure Raw Outputs

Raw command outputs captured on 2026-03-09. To update, re-run the commands below on the server
and paste the new output here.

```bash
ssh demotracker ip addr show
ssh demotracker ip -4 -6 add
ssh demotracker df -h
ssh demotracker "sudo tree /opt/torrust/storage/backup/"
```

## `ip addr show`

<!-- cspell:disable -->

```text
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 92:00:07:4f:b3:4f brd ff:ff:ff:ff:ff:ff
    inet 116.202.176.169/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet 116.202.177.184/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet 46.225.234.201/32 metric 100 scope global dynamic eth0
       valid_lft 76594sec preferred_lft 76594sec
    inet6 2a01:4f8:1c0c:828e::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 2a01:4f8:1c0c:9aae::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 2a01:4f8:1c19:620b::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::9000:7ff:fe4f:b34f/64 scope link
       valid_lft forever preferred_lft forever
3: br-39ad6ee3c1b0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 46:29:e7:97:3e:33 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.1/16 brd 172.18.255.255 scope global br-39ad6ee3c1b0
       valid_lft forever preferred_lft forever
    inet6 fe80::4429:e7ff:fe97:3e33/64 scope link
       valid_lft forever preferred_lft forever
4: br-51ba3f017631: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 06:6a:7e:ca:5c:d6 brd ff:ff:ff:ff:ff:ff
    inet 172.21.0.1/16 brd 172.21.255.255 scope global br-51ba3f017631
       valid_lft forever preferred_lft forever
    inet6 fe80::46a:7eff:feca:5cd6/64 scope link
       valid_lft forever preferred_lft forever
5: br-af49f2550e8d: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 46:72:53:cc:da:02 brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.1/16 brd 172.19.255.255 scope global br-af49f2550e8d
       valid_lft forever preferred_lft forever
    inet6 fe80::4472:53ff:fecc:da02/64 scope link
       valid_lft forever preferred_lft forever
6: br-de128721cfc1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 82:c6:7b:a7:17:75 brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/16 brd 172.20.255.255 scope global br-de128721cfc1
       valid_lft forever preferred_lft forever
    inet6 fe80::80c6:7bff:fea7:1775/64 scope link
       valid_lft forever preferred_lft forever
7: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether f6:61:6f:17:21:58 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
8: veth1884a17@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-de128721cfc1 state UP group default
    link/ether 8a:7f:dd:ec:e1:2c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::887f:ddff:feec:e12c/64 scope link
       valid_lft forever preferred_lft forever
9: vethbda793d@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-51ba3f017631 state UP group default
    link/ether 9e:c1:9e:05:3e:40 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::9cc1:9eff:fe05:3e40/64 scope link
       valid_lft forever preferred_lft forever
11: veth4aa917d@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-af49f2550e8d state UP group default
    link/ether 1e:8f:84:c9:ed:01 brd ff:ff:ff:ff:ff:ff link-netnsid 3
    inet6 fe80::1c8f:84ff:fec9:ed01/64 scope link
       valid_lft forever preferred_lft forever
12: veth51ffc8e@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-39ad6ee3c1b0 state UP group default
    link/ether 92:0c:87:e8:d6:25 brd ff:ff:ff:ff:ff:ff link-netnsid 4
    inet6 fe80::900c:87ff:fee8:d625/64 scope link
       valid_lft forever preferred_lft forever
13: vethbb2b0c3@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-af49f2550e8d state UP group default
    link/ether 4a:f7:51:b0:08:1c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::48f7:51ff:feb0:81c/64 scope link
       valid_lft forever preferred_lft forever
14: veth48074a8@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-39ad6ee3c1b0 state UP group default
    link/ether 1e:9f:91:a2:1b:78 brd ff:ff:ff:ff:ff:ff link-netnsid 3
    inet6 fe80::1c9f:91ff:fea2:1b78/64 scope link
       valid_lft forever preferred_lft forever
54: veth461d112@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-de128721cfc1 state UP group default
    link/ether 9a:f1:24:81:c9:60 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::98f1:24ff:fe81:c960/64 scope link
       valid_lft forever preferred_lft forever
55: veth4945dba@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-39ad6ee3c1b0 state UP group default
    link/ether be:69:cf:9e:af:59 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::bc69:cfff:fe9e:af59/64 scope link
       valid_lft forever preferred_lft forever
56: veth37e27ef@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-51ba3f017631 state UP group default
    link/ether 76:9d:28:c8:f8:95 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::749d:28ff:fec8:f895/64 scope link
       valid_lft forever preferred_lft forever
```

## `ip -4 -6 add`

```text
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 state UNKNOWN qlen 1000
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 2a01:4f8:1c0c:828e::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 2a01:4f8:1c0c:9aae::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 2a01:4f8:1c19:620b::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::9000:7ff:fe4f:b34f/64 scope link
       valid_lft forever preferred_lft forever
3: br-39ad6ee3c1b0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::4429:e7ff:fe97:3e33/64 scope link
       valid_lft forever preferred_lft forever
4: br-51ba3f017631: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::46a:7eff:feca:5cd6/64 scope link
       valid_lft forever preferred_lft forever
5: br-af49f2550e8d: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::4472:53ff:fecc:da02/64 scope link
       valid_lft forever preferred_lft forever
6: br-de128721cfc1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::80c6:7bff:fea7:1775/64 scope link
       valid_lft forever preferred_lft forever
8: veth1884a17@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::887f:ddff:feec:e12c/64 scope link
       valid_lft forever preferred_lft forever
9: vethbda793d@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::9cc1:9eff:fe05:3e40/64 scope link
       valid_lft forever preferred_lft forever
11: veth4aa917d@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::1c8f:84ff:fec9:ed01/64 scope link
       valid_lft forever preferred_lft forever
12: veth51ffc8e@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::900c:87ff:fee8:d625/64 scope link
       valid_lft forever preferred_lft forever
13: vethbb2b0c3@br-39ad6ee3c1b0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::48f7:51ff:feb0:81c/64 scope link
       valid_lft forever preferred_lft forever
14: veth48074a8@br-39ad6ee3c1b0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::1c9f:91ff:fea2:1b78/64 scope link
       valid_lft forever preferred_lft forever
54: veth461d112@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::98f1:24ff:fe81:c960/64 scope link
       valid_lft forever preferred_lft forever
55: veth4945dba@br-39ad6ee3c1b0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::bc69:cfff:fe9e:af59/64 scope link
       valid_lft forever preferred_lft forever
56: veth37e27ef@br-51ba3f017631: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP
    inet6 fe80::749d:28ff:fec8:f895/64 scope link
       valid_lft forever preferred_lft forever
```

<!-- cspell:enable -->

## `df -h`

```text
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           1.6G  1.4M  1.6G   1% /run
efivarfs        256K   27K  225K  11% /sys/firmware/efi/efivars
/dev/sda1       150G  5.0G  139G   4% /
tmpfs           7.7G     0  7.7G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda15      253M  146K  252M   1% /boot/efi
/dev/sdb         49G  264M   47G   1% /opt/torrust/storage
tmpfs           1.6G   12K  1.6G   1% /run/user/1000
```

## `tree /opt/torrust/storage/backup/`

```text
/opt/torrust/storage/backup/
├── config
│   ├── config_20260304_160759.tar.gz
│   ├── config_20260305_030013.tar.gz
│   ├── config_20260306_030013.tar.gz
│   ├── config_20260307_030014.tar.gz
│   ├── config_20260308_030014.tar.gz
│   └── config_20260309_030013.tar.gz
├── etc
│   ├── backup-paths.txt
│   └── backup.conf
└── mysql
    ├── mysql_20260304_160758.sql.gz
    ├── mysql_20260305_030013.sql.gz
    ├── mysql_20260306_030013.sql.gz
    ├── mysql_20260307_030014.sql.gz
    ├── mysql_20260308_030014.sql.gz
    └── mysql_20260309_030013.sql.gz

4 directories, 14 files
```
