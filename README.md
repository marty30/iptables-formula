iptables-formula
================

This module manages your firewall using iptables with pillar configured rules.
Thanks to the nature of Pillars it is possible to write global and local settings (e.g. enable globally, configure locally)

Pull requests are welcome for other platforms (or other improvements ofcourse!)

Usage
=====

All the configuration for the firewall is done via pillar (pillar.example).

Enable globally:
`pillars/firewall.sls`
```
firewall:
  enabled: True
  install: True  
  strict: True
```

Allow SSH:
`pillars/firewall/ssh.sls`
```
firewall:
  services:
    ssh:
      block_nomatch: False
      ips_allow:
        - 192.168.0.0/24
        - 10.0.2.2/32
```

Apply rules to specific interface:
```
firewall:
  services:
    ssh:
      interfaces:
        - eth0
        - eth1
```

Apply rules for multiple protocols:
```
firewall:
  services:
    ssh:
      protos:
        - udp
        - tcp
```

Allow an entire class such as your internal network:

```
  whitelist:
    networks:
      ips_allow:
        - 10.0.0.0/8
```

Salt combines both and effectively enables your firewall and applies the rules.

Notes:
 * Setting install to True will install `iptables` and `iptables-perrsistent` for you
 * Strict mode means: Deny **everything** except explicitly allowed (use with care!)
 * block_nomatch: With non-strict mode adds in a "REJECT" rule below the accept rules, otherwise other traffic to that service is still allowed. Can be defined per-service or globally, defaults to False.
 * Servicenames can be either port numbers or servicenames (e.g. ssh, zabbix-agent, http) and are available for viewing/configuring in `/etc/services`

Using iptables.service
======================

Salt can't merge pillars, so you can only define `firewall:services` in once place. With the firewall.service state and stateconf, you can define pillars for different services and include and extend the iptables.service state with the `parent` parameter to enable a default firewall configuration with special rules for different services.

`pillars/otherservice.sls`
```
otherservice:
  firewall:
    services:
      http:
        block_nomatch: False
        ips_allow:
          - 0.0.0.0/0
```

`states/otherservice.sls`
```
#!stateconf yaml . jinja

include:
  - iptables.service

extend:
  iptables.service::sls_params:
    stateconf.set:
      - parent: otherservice
```

Using iptables.nat
==================

You can use nat for interface. This is supported for IPv4 alone. IPv6 deployments should not use NAT.

```
  #Support nat
  # iptables -t nat -A POSTROUTING -o eth0 -s 192.168.18.0/24 -d 10.20.0.2 -j MASQUERADE

  nat:
    eth0:
      rules:
        '192.168.18.0/24':
          - 10.20.0.2
```

ICMP
====

The option `icmp` allows ICMP packets to get into the firewall. This should be enabled for network 
services to be working as per the RFCs as explained [here](https://serverfault.com/questions/702016/why-does-ip6tables-a-input-j-drop-blocks-outgoing-server-connections).

IPv6 Support
============

This formula supports IPv6 as long as it is activated with the option:

```
firewall:
  ipv6: True
```

Services and whitelists are supported under the sections `services_ipv6` and `whitelist_ipv6`, as below:

```
  services_ipv6:
    ssh:
      block_nomatch: False
      ips_allow:
        - 2a02:2028:773:d01:10a5:f34f:e7ff:f55b/64
        - 2a02:2028:773:d01:1814:28ef:e91b:70b8/64

  whitelist_ipv6:
    networks:
      ips_allow:
        - 2a02:2028:773:d01:1814:28ef:e91b:70b8/64
```

Similarly, an option to allow ICMP for IPv6 was also added:

```
firewall:
  icmpv6: True
```

These sections are only processed if the IPv6 support is activated.