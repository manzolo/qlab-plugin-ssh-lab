#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — Port Knocking${RESET}"; echo ""

knockd_status=$(ssh_server "systemctl is-active knockd 2>/dev/null" || echo "unknown")
assert_contains "knockd is active" "$knockd_status" "active"

assert "knockd config exists" ssh_server "test -f /etc/knockd.conf"
assert "knock command on client" ssh_client "which knock"

knockd_conf=$(ssh_server "cat /etc/knockd.conf")
assert_contains "Config has open sequence" "$knockd_conf" "7000|sequence"

report_results "Exercise 5"
