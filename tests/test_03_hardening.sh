#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — SSH Hardening${RESET}"; echo ""

ssh_server "sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak" >/dev/null 2>&1

# PermitRootLogin no
ssh_server "sudo sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config" >/dev/null
config=$(ssh_server "grep '^PermitRootLogin' /etc/ssh/sshd_config")
assert_contains "PermitRootLogin set to no" "$config" "no"

# MaxAuthTries
ssh_server "sudo sed -i 's/^#\\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config" >/dev/null
config2=$(ssh_server "grep '^MaxAuthTries' /etc/ssh/sshd_config")
assert_contains "MaxAuthTries set to 3" "$config2" "3"

# Validate config
config_test=$(ssh_server "sudo sshd -t 2>&1 || true")
assert_not_contains "Config is valid" "$config_test" "error"

# Reload (use ssh service name, may be ssh or sshd)
assert "SSH reload succeeds" ssh_server "sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null"
sleep 2

# Verify still accessible
assert "Server still reachable after hardening" ssh_server "echo ok"

# Restore
ssh_server "sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null" >/dev/null 2>&1 || true

report_results "Exercise 3"
