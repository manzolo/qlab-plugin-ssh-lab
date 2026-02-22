#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — SSH Anatomy${RESET}"; echo ""

status=$(ssh_server "systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null")
assert_contains "SSH service is active" "$status" "active"
assert "sshd_config exists" ssh_server "test -f /etc/ssh/sshd_config"

config=$(ssh_server "cat /etc/ssh/sshd_config")
assert_contains "Config has PubkeyAuthentication" "$config" "PubkeyAuthentication"

# SSH tools available on client
assert "Client has ssh-keygen" ssh_client "which ssh-keygen"
assert "Client has sshpass" ssh_client "which sshpass"

report_results "Exercise 1"
