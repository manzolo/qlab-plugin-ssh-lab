#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — Key-Based Authentication${RESET}"; echo ""

# Generate key on client
assert "Generate ed25519 key" ssh_client "ssh-keygen -t ed25519 -f ~/.ssh/test_key -N '' -q 2>/dev/null; true"
assert "Key files created" ssh_client "test -f ~/.ssh/test_key && test -f ~/.ssh/test_key.pub"

# Verify key format
key_type=$(ssh_client "ssh-keygen -l -f ~/.ssh/test_key.pub 2>/dev/null | head -1")
assert_contains "Key is ed25519" "$key_type" "ED25519"

# Generate RSA key for comparison
assert "Generate RSA key" ssh_client "ssh-keygen -t rsa -b 4096 -f ~/.ssh/test_rsa -N '' -q 2>/dev/null; true"
rsa_type=$(ssh_client "ssh-keygen -l -f ~/.ssh/test_rsa.pub 2>/dev/null | head -1")
assert_contains "RSA key is 4096 bits" "$rsa_type" "4096"

# Cleanup
ssh_client "rm -f ~/.ssh/test_key ~/.ssh/test_key.pub ~/.ssh/test_rsa ~/.ssh/test_rsa.pub" >/dev/null 2>&1

report_results "Exercise 2"
