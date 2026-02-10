#!/usr/bin/env bash
# ssh-lab run script — boots a VM for SSH hardening practice with fail2ban and port knocking

set -euo pipefail

PLUGIN_NAME="ssh-lab"
SSH_PORT=2234

echo "============================================="
echo "  ssh-lab: SSH Hardening Lab"
echo "============================================="
echo ""
echo "  This lab demonstrates:"
echo "    1. SSH key-based authentication"
echo "    2. fail2ban for brute-force protection"
echo "    3. Port knocking with knockd"
echo "    4. SSH daemon hardening (sshd_config)"
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

# Step 1: Download cloud image if not present
# Cloud images are pre-built OS images designed for cloud environments.
# They are minimal and expect cloud-init to configure them on first boot.
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  They are minimal and expect cloud-init to configure them on first boot."
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

# Step 2: Create cloud-init configuration
# cloud-init reads user-data to configure the VM on first boot:
#   - creates users, installs packages, writes config files, runs commands
info "Step 2: Cloud-init configuration"
echo ""
echo "  cloud-init will:"
echo "    - Create a user 'labuser' with SSH access"
echo "    - Install openssh-server, fail2ban, knockd, and iptables"
echo "    - Configure fail2ban for SSH brute-force protection"
echo "    - Set up knockd for port knocking"
echo ""

cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: ssh-lab
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
write_files:
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
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mssh-lab\033[0m — \033[1mSSH Hardening Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mObjectives:\033[0m
          • configure SSH key-based authentication
          • test fail2ban brute-force protection
          • practice port knocking with knockd
          • harden sshd_config settings

        \033[1;33mSSH Commands:\033[0m
          \033[0;32msudo systemctl status ssh\033[0m            SSH status
          \033[0;32msudo cat /etc/ssh/sshd_config\033[0m       SSH config
          \033[0;32mls -la ~/.ssh/\033[0m                      your SSH keys

        \033[1;33mfail2ban:\033[0m
          \033[0;32msudo fail2ban-client status\033[0m          overview
          \033[0;32msudo fail2ban-client status sshd\033[0m     SSH jail info
          \033[0;32msudo tail -f /var/log/auth.log\033[0m       auth log

        \033[1;33mPort Knocking (knockd):\033[0m
          \033[0;32msudo systemctl status knockd\033[0m         knockd status
          \033[0;32msudo cat /etc/knockd.conf\033[0m            knock config
          \033[0;32msudo iptables -L -n\033[0m                  firewall rules

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /etc/fail2ban/jail.local
    permissions: '0644'
    content: |
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
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
          command     = /usr/sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
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
  - mkdir -p /home/labuser/.ssh
  - ssh-keygen -t ed25519 -f /home/labuser/.ssh/id_ed25519 -N "" -C "labuser@ssh-lab"
  - cp /home/labuser/.ssh/id_ed25519.pub /home/labuser/.ssh/authorized_keys
  - chmod 700 /home/labuser/.ssh
  - chmod 600 /home/labuser/.ssh/authorized_keys /home/labuser/.ssh/id_ed25519
  - chmod 644 /home/labuser/.ssh/id_ed25519.pub
  - chown -R labuser:labuser /home/labuser
  - systemctl restart fail2ban
  - |
    # Detect the main network interface for knockd
    IFACE=$(ip route show default | awk '{print $5}' | head -1)
    if [ -n "$IFACE" ]; then
      sed -i "s/^#\?KNOCKD_OPTS=.*/KNOCKD_OPTS=\"-i $IFACE\"/" /etc/default/knockd 2>/dev/null || true
      sed -i 's/^#\?START_KNOCKD=.*/START_KNOCKD=1/' /etc/default/knockd 2>/dev/null || true
    fi
  - systemctl enable knockd || true
  - systemctl start knockd || true
  - echo "=== ssh-lab VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data"

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: ${PLUGIN_NAME}-001
local-hostname: ${PLUGIN_NAME}
METADATA

success "Created cloud-init files in $LAB_DIR/"
echo ""

# Step 3: Generate cloud-init ISO
# QEMU reads cloud-init data from a small ISO image (CD-ROM).
# We use genisoimage to create it with the 'cidata' volume label.
info "Step 3: Cloud-init ISO"
echo ""
echo "  QEMU reads cloud-init data from a small ISO image (CD-ROM)."
echo "  We use genisoimage to create it with the 'cidata' volume label."
echo ""

CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"
echo ""

# Step 4: Create overlay disk
# An overlay disk uses copy-on-write (COW) on top of the base image.
# The original cloud image stays untouched; all writes go to the overlay.
info "Step 4: Overlay disk"
echo ""
echo "  An overlay disk uses copy-on-write (COW) on top of the base image."
echo "  This means:"
echo "    - The original cloud image stays untouched"
echo "    - All writes go to the overlay file"
echo "    - You can reset the lab by deleting the overlay"
echo ""

OVERLAY_DISK="$LAB_DIR/${PLUGIN_NAME}-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    info "Removing previous overlay disk..."
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK" "${QLAB_DISK_SIZE:-}"
echo ""

# Step 5: Boot the VM in background
info "Step 5: Starting VM in background"
echo ""
echo "  The VM will run in background with:"
echo "    - Serial output logged to .qlab/logs/$PLUGIN_NAME.log"
echo "    - SSH access on port $SSH_PORT"
echo ""

start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" "$SSH_PORT"

echo ""
echo "============================================="
echo "  ssh-lab: VM is booting"
echo "============================================="
echo ""
echo "  Credentials:"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Connect via SSH (wait ~60s for boot + package install):"
echo "    qlab shell ${PLUGIN_NAME}"
echo ""
echo "  Port knocking sequence (to open SSH from inside VM):"
echo "    Open:  knock <target> 7000 8000 9000"
echo "    Close: knock <target> 9000 8000 7000"
echo ""
echo "  View boot log:"
echo "    qlab log ${PLUGIN_NAME}"
echo ""
echo "  Stop VM:"
echo "    qlab stop ${PLUGIN_NAME}"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
