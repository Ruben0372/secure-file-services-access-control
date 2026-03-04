#!/usr/bin/env bash
#
# set-directory-permissions.sh
# Creates the share directory structure and applies the permission model.
# Run with: sudo bash set-directory-permissions.sh [mount-path]
#
# This script is idempotent — safe to run multiple times.

set -euo pipefail

# --- Configuration ---
MOUNT_PATH="${1:-/mnt/WaRlOrD}"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Checks ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

if [[ ! -d "$MOUNT_PATH" ]]; then
    error "Mount path '$MOUNT_PATH' does not exist"
    echo "Make sure the drive is mounted before running this script."
    exit 1
fi

# Verify required groups exist
for group in samba-admins samba-standard samba-guests; do
    if ! getent group "$group" > /dev/null 2>&1; then
        error "Group '$group' does not exist. Run create-user-tiers.sh first."
        exit 1
    fi
done

# --- Create Directories ---
echo ""
echo "=== Creating Directory Structure ==="

for dir in admin-vault shared media; do
    if [[ -d "$MOUNT_PATH/$dir" ]]; then
        warn "Directory '$MOUNT_PATH/$dir' already exists"
    else
        mkdir -p "$MOUNT_PATH/$dir"
        info "Created '$MOUNT_PATH/$dir'"
    fi
done

# --- Apply Permissions ---
echo ""
echo "=== Applying Permissions ==="

# Admin vault — only samba-admins (2770 = rwxrws---)
chown root:samba-admins "$MOUNT_PATH/admin-vault"
chmod 2770 "$MOUNT_PATH/admin-vault"
info "admin-vault → root:samba-admins 2770"

# Shared storage — samba-standard (admins are also in this group) (2775 = rwxrwsr-x)
chown root:samba-standard "$MOUNT_PATH/shared"
chmod 2775 "$MOUNT_PATH/shared"
info "shared → root:samba-standard 2775"

# Media library — samba-standard owns, guests get read via Samba config (2775 = rwxrwsr-x)
chown root:samba-standard "$MOUNT_PATH/media"
chmod 2775 "$MOUNT_PATH/media"
info "media → root:samba-standard 2775"

# --- Verify ---
echo ""
echo "=== Verification ==="
echo ""

printf "%-30s %-20s %-10s %-5s\n" "DIRECTORY" "OWNER:GROUP" "MODE" "SGID"
printf "%-30s %-20s %-10s %-5s\n" "------------------------------" "--------------------" "----------" "-----"

for dir in admin-vault shared media; do
    path="$MOUNT_PATH/$dir"
    owner=$(stat -c '%U:%G' "$path" 2>/dev/null || stat -f '%Su:%Sg' "$path")
    mode=$(stat -c '%a' "$path" 2>/dev/null || stat -f '%A' "$path")

    # Check setgid
    if [[ $(stat -c '%a' "$path" 2>/dev/null || echo "0") -ge 2000 ]] || \
       ls -ld "$path" | grep -q '^d..x..s'; then
        sgid="YES"
    else
        sgid="NO"
    fi

    printf "%-30s %-20s %-10s %-5s\n" "$path" "$owner" "$mode" "$sgid"
done

echo ""
info "Directory permissions applied successfully."
