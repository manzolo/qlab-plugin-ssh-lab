#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — Security Scanning${RESET}"; echo ""

assert "nmap is installed on client" ssh_client "which nmap"
assert "hydra is installed on client" ssh_client "which hydra"
assert "sshpass is installed on client" ssh_client "which sshpass"

# Scan localhost as a basic test
scan=$(ssh_client "nmap -p 22 localhost 2>/dev/null")
assert_contains "nmap can scan SSH port" "$scan" "22/tcp|ssh"

report_results "Exercise 6"
