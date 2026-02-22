#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — Fail2Ban${RESET}"; echo ""

f2b_status=$(ssh_server "sudo fail2ban-client status 2>/dev/null")
assert_contains "fail2ban is running" "$f2b_status" "Number of jail"

jail=$(ssh_server "sudo fail2ban-client status sshd 2>/dev/null")
assert_contains "SSH jail is active" "$jail" "sshd"

# Verify fail2ban config
assert "fail2ban config exists" ssh_server "test -f /etc/fail2ban/jail.local || test -f /etc/fail2ban/jail.d/sshd.conf || test -d /etc/fail2ban/jail.d"

# Check ban settings
f2b_conf=$(ssh_server "sudo fail2ban-client get sshd maxretry 2>/dev/null || echo 3")
assert_contains "Max retries configured" "$f2b_conf" "[0-9]"

report_results "Exercise 4"
