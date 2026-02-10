#!/usr/bin/env bash
# ssh-lab install script

set -euo pipefail

echo ""
echo "  [ssh-lab] Installing..."
echo ""
echo "  This plugin demonstrates SSH hardening techniques inside"
echo "  a QEMU VM with fail2ban, port knocking, and key authentication."
echo ""
echo "  What you will learn:"
echo "    - How to configure SSH key-based authentication"
echo "    - How to set up fail2ban for brute-force protection"
echo "    - How to implement port knocking with knockd"
echo "    - How to harden sshd_config for better security"
echo "    - How to analyze SSH authentication logs"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [ssh-lab] Installation complete."
echo "  Run with: qlab run ssh-lab"
