# ssh-lab — SSH Hardening & Security Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots two virtual machines for hands-on SSH hardening practice: a **server** to defend (fail2ban, knockd, key authentication) and a **client** to attack from (nmap, hydra, sshpass).

## Architecture

```
┌──────────────────────────┐        ┌──────────────────────────┐
│    ssh-lab-server        │        │    ssh-lab-client        │
│    (Defender)            │        │    (Attacker)            │
│                          │        │                          │
│  sshd, fail2ban, knock   │◄───────│  nmap, hydra, sshpass    │
│  iptables, rsyslog       │  LAN   │  knock, curl             │
│                          │        │                          │
│  LAN IP: 192.168.100.1   │        │  LAN IP: 192.168.100.2   │
│  Host SSH port: dynamic  │        │  Host SSH port: dynamic  │
└──────────┬───────────────┘        └───────────┬──────────────┘
           │  192.168.100.0/24 (internal LAN)   │
           └────────────────┬───────────────────┘
                            │ QEMU socket multicast
                   ┌────────┴────────┐
                   │   QEMU Host     │
                   │  qlab shell ... │
                   └─────────────────┘
```

The two VMs are connected by an **internal LAN** (QEMU socket multicast) with dedicated IPs. The client reaches the server directly at `192.168.100.1:22`. Host access via `qlab shell` uses separate port forwarding and is **not affected** by fail2ban bans on the internal LAN.

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

## Ports

| VM              | Host SSH Port | Internal LAN IP  | Service     |
|-----------------|---------------|------------------|-------------|
| ssh-lab-server  | dynamic       | 192.168.100.1    | SSH (sshd)  |
| ssh-lab-client  | dynamic       | 192.168.100.2    | SSH (shell) |

> All host ports are dynamically allocated. Use `qlab ports` to see the actual mappings.

## Usage

```bash
# Install the plugin
qlab install ssh-lab

# Run the lab (boots both VMs)
qlab run ssh-lab

# Wait ~90s for boot and package installation, then:

# Connect to the server (defender)
qlab shell ssh-lab-server

# Connect to the client (attacker)
qlab shell ssh-lab-client

# View boot logs
qlab log ssh-lab-server
qlab log ssh-lab-client

# Stop both VMs
qlab stop ssh-lab

# Stop a single VM
qlab stop ssh-lab-server
qlab stop ssh-lab-client
```

## Exercises

> **New to SSH hardening?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with full examples.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **SSH Anatomy** | Explore SSH daemon, config files, and key types |
| 2 | **Key-Based Authentication** | Generate keys, deploy, disable password auth |
| 3 | **SSH Hardening** | Apply security best practices to sshd_config |
| 4 | **Fail2Ban** | Configure brute-force protection, trigger bans, unban |
| 5 | **Port Knocking** | Use knockd to hide SSH behind a knock sequence |
| 6 | **Security Scanning** | Analyze auth logs and scan with nmap/hydra |

## Automated Tests

An automated test suite validates the exercises against running VMs:

```bash
# Start the lab first
qlab run ssh-lab
# Wait ~90s for cloud-init, then run all tests
qlab test ssh-lab
```

## Resetting

To start fresh, stop and re-run:

```bash
qlab stop ssh-lab
qlab run ssh-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
