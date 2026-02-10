# ssh-lab — SSH Hardening & Security Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots a virtual machine pre-configured with SSH hardening tools: fail2ban, port knocking (knockd), and SSH key authentication.

## Objectives

- Configure SSH key-based authentication
- Set up and test fail2ban brute-force protection
- Implement port knocking with knockd
- Harden sshd_config settings for better security
- Analyze SSH authentication logs

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu 22.04 cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` with openssh-server, fail2ban, knockd, and key pair setup
3. **ISO generation**: Packs cloud-init files into a small ISO (cidata)
4. **Overlay disk**: Creates a COW disk on top of the base image (original stays untouched)
5. **QEMU boot**: Starts the VM in background with SSH port forwarding

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

## Ports

| Service | Host Port | VM Port |
|---------|-----------|---------|
| SSH     | 2234      | 22      |

## Usage

```bash
# Install the plugin
qlab install ssh-lab

# Run the lab
qlab run ssh-lab

# Wait ~60s for boot and package installation, then:

# Connect via SSH
qlab shell ssh-lab

# Inside the VM:
#   - Check fail2ban: sudo fail2ban-client status sshd
#   - Check knockd: sudo systemctl status knockd
#   - View SSH keys: ls -la ~/.ssh/
#   - View auth log: sudo tail -f /var/log/auth.log

# Stop the VM
qlab stop ssh-lab
```

## Exercises

1. **SSH key authentication**: Examine the auto-generated ed25519 key pair in `~/.ssh/` and understand how `authorized_keys` works
2. **Test fail2ban**: Intentionally trigger 3+ failed SSH login attempts and verify the IP gets banned with `sudo fail2ban-client status sshd`
3. **Port knocking**: Review the knockd config at `/etc/knockd.conf` — the sequence `7000,8000,9000` opens SSH, `9000,8000,7000` closes it
4. **Harden sshd_config**: Edit `/etc/ssh/sshd_config` to disable password auth (`PasswordAuthentication no`), disable root login, and change the port
5. **Audit log analysis**: Examine `/var/log/auth.log` to identify failed login attempts and understand what fail2ban monitors

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
