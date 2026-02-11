#!/usr/bin/env bash
# ssh-lab run script — boots two VMs for SSH hardening practice:
#   server (fail2ban, knockd, sshd hardening) + client (attack/testing tools)
# VMs communicate over an internal LAN via QEMU socket multicast.

set -euo pipefail

PLUGIN_NAME="ssh-lab"
SERVER_VM="ssh-lab-server"
CLIENT_VM="ssh-lab-client"
SERVER_SSH_PORT=2234
CLIENT_SSH_PORT=2235

# Internal LAN — direct VM-to-VM link via QEMU socket multicast
INTERNAL_MCAST="230.0.0.1:10001"
SERVER_INTERNAL_IP="192.168.100.1"
CLIENT_INTERNAL_IP="192.168.100.2"
SERVER_LAN_MAC="52:54:00:00:02:01"
CLIENT_LAN_MAC="52:54:00:00:02:02"

echo "============================================="
echo "  ssh-lab: SSH Hardening Lab"
echo "============================================="
echo ""
echo "  This lab creates two VMs on an internal LAN:"
echo ""
echo "    1. $SERVER_VM  (SSH port $SERVER_SSH_PORT)"
echo "       Internal IP: $SERVER_INTERNAL_IP"
echo "       SSH server with fail2ban, knockd, key authentication"
echo "       Role: defend this machine"
echo ""
echo "    2. $CLIENT_VM  (SSH port $CLIENT_SSH_PORT)"
echo "       Internal IP: $CLIENT_INTERNAL_IP"
echo "       Equipped with nmap, hydra, sshpass, knock client"
echo "       Role: test the server's defenses"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1024)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by both VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  Both VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for both VMs"
echo ""

# --- Server VM cloud-init ---
info "Creating cloud-init for $SERVER_VM..."

cat > "$LAB_DIR/user-data-server" <<'USERDATA'
#cloud-config
hostname: ssh-lab-server
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - openssh-server
  - fail2ban
  - knockd
  - iptables
  - net-tools
  - rsyslog
write_files:
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          sshlan:
            match:
              macaddress: "__SERVER_LAN_MAC__"
            addresses:
              - __SERVER_INTERNAL_IP__/24
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mssh-lab-server\033[0m — \033[1mSSH Server (Defender)\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Defend this machine — harden SSH, monitor attacks
        \033[1;33mInternal IP:\033[0m  __SERVER_INTERNAL_IP__

        \033[1;33mQuick status:\033[0m
          \033[0;32msudo systemctl status sshd\033[0m             SSH daemon
          \033[0;32msudo fail2ban-client status sshd\033[0m       fail2ban jail
          \033[0;32msudo systemctl status knockd\033[0m           port knocking

        \033[1;33mConfig files:\033[0m
          \033[0;32m/etc/ssh/sshd_config\033[0m                   SSH config
          \033[0;32m/etc/fail2ban/jail.local\033[0m               fail2ban rules
          \033[0;32m/etc/knockd.conf\033[0m                       knock sequences

        \033[1;33mLog monitoring:\033[0m
          \033[0;32msudo tail -f /var/log/auth.log\033[0m         auth log (live)

        \033[1;33mFirewall & Port Knocking:\033[0m
          \033[0;32msudo iptables -L -n\033[0m                    current rules
          SSH from LAN is blocked by default (iptables DROP)
          Knock sequence: \033[0;32m7000, 8000, 9000\033[0m to open
          Reverse:        \033[0;32m9000, 8000, 7000\033[0m to close

        \033[1;33mSSH keys:\033[0m
          \033[0;32mls -la ~/.ssh/\033[0m                         your SSH keys
          \033[0;32mcat ~/.ssh/authorized_keys\033[0m             authorized keys

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

  - path: /etc/fail2ban/jail.local
    permissions: '0644'
    content: |
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
      backend = auto
      maxretry = 3
      bantime = 3600
      findtime = 600
  - path: /etc/knockd.conf
    permissions: '0644'
    content: |
      [options]
          UseSyslog

      [openSSH]
          sequence    = 7000,8000,9000
          seq_timeout = 5
          command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
          tcpflags    = syn

      [closeSSH]
          sequence    = 9000,8000,7000
          seq_timeout = 5
          command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
          tcpflags    = syn
runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - netplan apply
  - mkdir -p /home/labuser/.ssh
  - ssh-keygen -t ed25519 -f /home/labuser/.ssh/id_ed25519 -N "" -C "labuser@ssh-lab"
  - cat /home/labuser/.ssh/id_ed25519.pub >> /home/labuser/.ssh/authorized_keys
  - chmod 700 /home/labuser/.ssh
  - chmod 600 /home/labuser/.ssh/authorized_keys /home/labuser/.ssh/id_ed25519
  - chmod 644 /home/labuser/.ssh/id_ed25519.pub
  - chown -R labuser:labuser /home/labuser
  - systemctl enable rsyslog
  - systemctl restart rsyslog
  - systemctl restart fail2ban
  - |
    # Find the internal LAN interface by MAC address for knockd
    IFACE=$(ip -o link | grep -i "__SERVER_LAN_MAC__" | awk -F': ' '{print $2}')
    if [ -z "$IFACE" ]; then
      # Fallback: detect default interface
      IFACE=$(ip route show default | awk '{print $5}' | head -1)
    fi
    if [ -n "$IFACE" ]; then
      sed -i "s/^#\?KNOCKD_OPTS=.*/KNOCKD_OPTS=\"-i $IFACE\"/" /etc/default/knockd 2>/dev/null || true
      sed -i 's/^#\?START_KNOCKD=.*/START_KNOCKD=1/' /etc/default/knockd 2>/dev/null || true
    fi
  - systemctl enable knockd || true
  - systemctl start knockd || true
  - iptables -A INPUT -s 192.168.100.0/24 -p tcp --dport 22 -j DROP
  - echo "=== ssh-lab-server VM is ready! ==="
USERDATA

# Inject variables into server user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-server"
sed -i "s|__SERVER_LAN_MAC__|${SERVER_LAN_MAC}|g" "$LAB_DIR/user-data-server"
sed -i "s|__SERVER_INTERNAL_IP__|${SERVER_INTERNAL_IP}|g" "$LAB_DIR/user-data-server"

cat > "$LAB_DIR/meta-data-server" <<METADATA
instance-id: ${SERVER_VM}-001
local-hostname: ${SERVER_VM}
METADATA

success "Created cloud-init for $SERVER_VM"

# --- Client VM cloud-init ---
info "Creating cloud-init for $CLIENT_VM..."

cat > "$LAB_DIR/user-data-client" <<'USERDATA'
#cloud-config
hostname: ssh-lab-client
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
package_update: true
packages:
  - openssh-client
  - nmap
  - knockd
  - hydra
  - sshpass
  - net-tools
  - curl
write_files:
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          sshlan:
            match:
              macaddress: "__CLIENT_LAN_MAC__"
            addresses:
              - __CLIENT_INTERNAL_IP__/24
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;31mssh-lab-client\033[0m — \033[1mSSH Client (Attacker)\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Test the server's defenses
        \033[1;33mInternal IP:\033[0m  __CLIENT_INTERNAL_IP__

        \033[1;33mTarget (server):\033[0m
          \033[0;32mssh labuser@__SERVER_INTERNAL_IP__\033[0m             connect to server

        \033[1;33mAttack tools:\033[0m
          \033[0;32mhydra -l labuser -P passwords.txt ssh://__SERVER_INTERNAL_IP__\033[0m
                                                    brute-force test
          \033[0;32msshpass -p wrong ssh labuser@__SERVER_INTERNAL_IP__\033[0m
                                                    manual failed login
          \033[0;32mnmap -sV -p 22 __SERVER_INTERNAL_IP__\033[0m         port scan
          \033[0;32mknock __SERVER_INTERNAL_IP__ 7000 8000 9000\033[0m   port knocking

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - netplan apply
  - echo "=== ssh-lab-client VM is ready! ==="
USERDATA

# Inject variables into client user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-client"
sed -i "s|__CLIENT_LAN_MAC__|${CLIENT_LAN_MAC}|g" "$LAB_DIR/user-data-client"
sed -i "s|__CLIENT_INTERNAL_IP__|${CLIENT_INTERNAL_IP}|g" "$LAB_DIR/user-data-client"
sed -i "s|__SERVER_INTERNAL_IP__|${SERVER_INTERNAL_IP}|g" "$LAB_DIR/user-data-client"

cat > "$LAB_DIR/meta-data-client" <<METADATA
instance-id: ${CLIENT_VM}-001
local-hostname: ${CLIENT_VM}
METADATA

success "Created cloud-init for $CLIENT_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_SERVER="$LAB_DIR/cidata-server.iso"
genisoimage -output "$CIDATA_SERVER" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-server" "meta-data=$LAB_DIR/meta-data-server" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_SERVER"

CIDATA_CLIENT="$LAB_DIR/cidata-client.iso"
genisoimage -output "$CIDATA_CLIENT" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-client" "meta-data=$LAB_DIR/meta-data-client" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_CLIENT"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_SERVER="$LAB_DIR/${SERVER_VM}-disk.qcow2"
if [[ -f "$OVERLAY_SERVER" ]]; then rm -f "$OVERLAY_SERVER"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_SERVER" "${QLAB_DISK_SIZE:-}"

OVERLAY_CLIENT="$LAB_DIR/${CLIENT_VM}-disk.qcow2"
if [[ -f "$OVERLAY_CLIENT" ]]; then rm -f "$OVERLAY_CLIENT"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_CLIENT" "${QLAB_DISK_SIZE:-}"
echo ""

# =============================================
# Step 5: Start both VMs
# =============================================
info "Step 5: Starting VMs"
echo ""

info "Starting $SERVER_VM (SSH port $SERVER_SSH_PORT, LAN $SERVER_INTERNAL_IP)..."
start_vm "$OVERLAY_SERVER" "$CIDATA_SERVER" "$MEMORY" "$SERVER_VM" "$SERVER_SSH_PORT" \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${SERVER_LAN_MAC}"
echo ""

info "Starting $CLIENT_VM (SSH port $CLIENT_SSH_PORT, LAN $CLIENT_INTERNAL_IP)..."
start_vm "$OVERLAY_CLIENT" "$CIDATA_CLIENT" "$MEMORY" "$CLIENT_VM" "$CLIENT_SSH_PORT" \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${CLIENT_LAN_MAC}"

echo ""
echo "============================================="
echo "  ssh-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  Server VM (defender):"
echo "    SSH:          qlab shell $SERVER_VM"
echo "    Log:          qlab log $SERVER_VM"
echo "    Host port:    $SERVER_SSH_PORT"
echo "    Internal IP:  $SERVER_INTERNAL_IP"
echo "    Services:     sshd, fail2ban, knockd"
echo ""
echo "  Client VM (attacker):"
echo "    SSH:          qlab shell $CLIENT_VM"
echo "    Log:          qlab log $CLIENT_VM"
echo "    Host port:    $CLIENT_SSH_PORT"
echo "    Internal IP:  $CLIENT_INTERNAL_IP"
echo "    Tools:        nmap, hydra, sshpass, knock"
echo ""
echo "  Internal LAN:   $SERVER_INTERNAL_IP <-> $CLIENT_INTERNAL_IP"
echo "  From client:    ssh labuser@$SERVER_INTERNAL_IP"
echo ""
echo "  Credentials (both VMs):"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Wait ~90s for boot + package installation."
echo ""
echo "  Stop both VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Stop a single VM:"
echo "    qlab stop $SERVER_VM"
echo "    qlab stop $CLIENT_VM"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
