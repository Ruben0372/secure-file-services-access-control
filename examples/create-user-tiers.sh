#!/usr/bin/env bash
#
# create-user-tiers.sh
# Creates the 3 Samba groups and sample users for each tier.
# Run with: sudo bash create-user-tiers.sh
#
# This script is idempotent — safe to run multiple times.

set -euo pipefail

# --- Configuration ---
ADMIN_USER="${1:-}"
STANDARD_USER="${2:-}"
GUEST_USER="${3:-}"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[SKIP]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Checks ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

if [[ -z "$ADMIN_USER" || -z "$STANDARD_USER" || -z "$GUEST_USER" ]]; then
    echo "Usage: sudo bash create-user-tiers.sh <admin-user> <standard-user> <guest-user>"
    echo ""
    echo "Example: sudo bash create-user-tiers.sh user1 user2 user3"
    exit 1
fi

# --- Create Groups ---
echo ""
echo "=== Creating Samba Groups ==="

for group in samba-admins samba-standard samba-guests; do
    if getent group "$group" > /dev/null 2>&1; then
        warn "Group '$group' already exists"
    else
        groupadd "$group"
        info "Created group '$group'"
    fi
done

# --- Create/Assign Admin User ---
echo ""
echo "=== Setting Up Admin User: $ADMIN_USER ==="

if ! id "$ADMIN_USER" > /dev/null 2>&1; then
    useradd -m "$ADMIN_USER"
    info "Created Linux user '$ADMIN_USER'"
else
    warn "Linux user '$ADMIN_USER' already exists"
fi

usermod -aG samba-admins "$ADMIN_USER"
info "Added '$ADMIN_USER' to samba-admins"

usermod -aG samba-standard "$ADMIN_USER"
info "Added '$ADMIN_USER' to samba-standard"

# --- Create/Assign Standard User ---
echo ""
echo "=== Setting Up Standard User: $STANDARD_USER ==="

if ! id "$STANDARD_USER" > /dev/null 2>&1; then
    useradd -m -s /bin/nologin "$STANDARD_USER"
    info "Created Linux user '$STANDARD_USER' (no shell login)"
else
    warn "Linux user '$STANDARD_USER' already exists"
fi

usermod -aG samba-standard "$STANDARD_USER"
info "Added '$STANDARD_USER' to samba-standard"

# --- Create/Assign Guest User ---
echo ""
echo "=== Setting Up Guest User: $GUEST_USER ==="

if ! id "$GUEST_USER" > /dev/null 2>&1; then
    useradd -m -s /bin/nologin "$GUEST_USER"
    info "Created Linux user '$GUEST_USER' (no shell login)"
else
    warn "Linux user '$GUEST_USER' already exists"
fi

usermod -aG samba-guests "$GUEST_USER"
info "Added '$GUEST_USER' to samba-guests"

# --- Add Users to Samba Database ---
echo ""
echo "=== Adding Users to Samba Database ==="
echo "You will be prompted to set a Samba password for each user."
echo ""

for user in "$ADMIN_USER" "$STANDARD_USER" "$GUEST_USER"; do
    if pdbedit -L 2>/dev/null | grep -q "^${user}:"; then
        warn "Samba user '$user' already exists"
    else
        echo "--- Set Samba password for: $user ---"
        smbpasswd -a "$user"
        smbpasswd -e "$user"
        info "Added and enabled Samba user '$user'"
    fi
done

# --- Summary ---
echo ""
echo "=== Summary ==="
echo ""
echo "Groups:"
for group in samba-admins samba-standard samba-guests; do
    members=$(getent group "$group" | cut -d: -f4)
    echo "  $group: $members"
done
echo ""
echo "Samba users:"
pdbedit -L 2>/dev/null | sed 's/^/  /'
echo ""
info "User tier setup complete."
