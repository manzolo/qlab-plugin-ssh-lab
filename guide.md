# SSH Lab — Step-by-Step Guide

This guide walks you through **SSH (Secure Shell)** hardening — the process of making an SSH server resistant to attacks. SSH is the primary remote access protocol for Linux servers, and a misconfigured SSH server is one of the most common attack vectors.

By the end of this lab you will understand SSH authentication methods, key-based login, server hardening, fail2ban intrusion prevention, and port knocking.

## Prerequisites

```bash
qlab run ssh-lab
```

Open **two terminals**:

```bash
# Terminal 1 — Server
qlab shell ssh-lab-server

# Terminal 2 — Client (attacker tools)
qlab shell ssh-lab-client
```

```bash
cloud-init status --wait
```

## Network Topology

```
        Host Machine
       ┌────────────┐
       │  SSH :auto │──────► ssh-lab-server
       │  SSH :auto │──────► ssh-lab-client
       └────────────┘

   Internal LAN (192.168.100.0/24)
  ┌──────────────────────────────────────┐
  │  ┌──────────────┐ ┌──────────────┐  │
  │  │ ssh-server   │ │ ssh-client   │  │
  │  │ 192.168.100.1│ │ 192.168.100.2│  │
  │  │ fail2ban     │ │ nmap, hydra  │  │
  │  │ knockd       │ │ sshpass      │  │
  │  └──────────────┘ └──────────────┘  │
  └──────────────────────────────────────┘
```

## Credentials

- **Username:** `labuser` / **Password:** `labpass` (both VMs)

---

## Exercise 01 — SSH Anatomy

**Goal:** Understand SSH configuration and authentication methods.

### 1.1 Check sshd on server

```bash
systemctl status sshd
```

### 1.2 Explore sshd_config

```bash
cat /etc/ssh/sshd_config | grep -v '^#' | grep -v '^$'
```

Key settings: `Port`, `PermitRootLogin`, `PasswordAuthentication`, `PubkeyAuthentication`.

### 1.3 Connect from client to server

On **ssh-lab-client**:
```bash
sshpass -p labpass ssh -o StrictHostKeyChecking=no labuser@192.168.100.1 "hostname"
```

**Expected output:** `ssh-lab-server` (or similar)

**Verification:** SSH server is running and client can connect via internal LAN.

---

## Exercise 02 — Key-Based Authentication

**Goal:** Understand SSH key generation and key types.

### 2.1 Generate an ed25519 key pair on client

On **ssh-lab-client**:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/test_key -N ""
```

### 2.2 Verify key files and type

```bash
test -f ~/.ssh/test_key && test -f ~/.ssh/test_key.pub && echo "Key files created"
ssh-keygen -l -f ~/.ssh/test_key.pub
```

**Expected output:** The fingerprint line should contain `ED25519`.

### 2.3 Generate an RSA key for comparison

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/test_rsa -N ""
ssh-keygen -l -f ~/.ssh/test_rsa.pub
```

**Expected output:** The fingerprint line should show `4096` bits.

### 2.4 Cleanup

```bash
rm -f ~/.ssh/test_key ~/.ssh/test_key.pub ~/.ssh/test_rsa ~/.ssh/test_rsa.pub
```

**Verification:** Both ed25519 and RSA keys can be generated and inspected. Ed25519 is preferred for modern deployments due to shorter keys and faster operations.

---

## Exercise 03 — SSH Hardening

**Goal:** Harden the SSH server configuration.

### 3.1 Backup config

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

### 3.2 Disable root login

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```

### 3.3 Limit authentication attempts

```bash
sudo sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```

### 3.4 Restore config

```bash
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl reload sshd
```

**Verification:** Hardening changes take effect and can be reverted.

---

## Exercise 04 — Fail2Ban

**Goal:** Use fail2ban to automatically ban brute-force attackers.

fail2ban monitors log files for failed authentication attempts and temporarily bans the offending IP address using firewall rules.

### 4.1 Check fail2ban status on server

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### 4.2 Trigger failed logins from client

On **ssh-lab-client**, attempt 4+ failed logins:
```bash
for i in 1 2 3 4; do sshpass -p wrongpass ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no labuser@192.168.100.1 "echo" 2>/dev/null; done
```

### 4.3 Check banned IPs on server

```bash
sudo fail2ban-client status sshd
```

You should see `192.168.100.2` in the banned list.

### 4.4 Unban

```bash
sudo fail2ban-client set sshd unbanip 192.168.100.2
```

**Verification:** Failed logins trigger a ban, and the IP can be unbanned.

---

## Exercise 05 — Port Knocking

**Goal:** Hide SSH behind a port knock sequence.

Port knocking adds a layer of defense: SSH port is blocked by default and only opens after a specific sequence of connection attempts to other ports.

### 5.1 Check knockd config on server

```bash
cat /etc/knockd.conf
```

### 5.2 Knock sequence from client

```bash
knock 192.168.100.1 7000 8000 9000
```

### 5.3 Connect via SSH

```bash
sshpass -p labpass ssh -o StrictHostKeyChecking=no labuser@192.168.100.1 "echo knock-works"
```

### 5.4 Close with reverse sequence

```bash
knock 192.168.100.1 9000 8000 7000
```

**Verification:** SSH only accessible after correct knock sequence.

---

## Exercise 06 — Security Scanning

**Goal:** Understand what attackers see when scanning your server.

### 6.1 Port scan from client

```bash
nmap 192.168.100.1
```

### 6.2 Service detection

```bash
nmap -sV 192.168.100.1 -p 22
```

### 6.3 Check server logs for evidence

On **ssh-lab-server**:
```bash
sudo journalctl -u sshd --no-pager -n 20
```

**Verification:** nmap can scan the server and server logs show evidence.

---

## Troubleshooting

### Can't connect between VMs
```bash
ping 192.168.100.1  # from client
ping 192.168.100.2  # from server
```

### fail2ban not banning
```bash
sudo fail2ban-client status sshd
sudo journalctl -u fail2ban --no-pager -n 20
```

### Locked out after hardening
```bash
# Use backup SSH session or reset
qlab stop ssh-lab && qlab run ssh-lab
```
