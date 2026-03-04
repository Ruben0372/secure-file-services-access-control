# Samba Setup Guide

Step-by-step guide to setting up a Samba file server with tiered access control on Linux.

## Prerequisites

- Linux server (this guide uses Arch Linux, commands noted for Ubuntu/Debian)
- A dedicated storage drive (this setup uses a 7.3TB drive at `/dev/sdd1`)
- Root or sudo access

## Phase 1: Mount the Storage Drive

### 1.1 Identify the Drive

```bash
# List all block devices
lsblk

# Get filesystem type and UUID
sudo blkid /dev/sdd1
```

### 1.2 Create Mount Point and Mount

```bash
# Create mount point
sudo mkdir -p /mnt/WaRlOrD

# Mount (adjust filesystem type as needed)
# For ext4:
sudo mount -t ext4 /dev/sdd1 /mnt/WaRlOrD

# For NTFS:
# sudo mount -t ntfs-3g /dev/sdd1 /mnt/WaRlOrD

# For exFAT:
# sudo mount -t exfat /dev/sdd1 /mnt/WaRlOrD

# Verify
df -h /mnt/WaRlOrD
```

### 1.3 Make the Mount Permanent

Get the drive UUID:

```bash
sudo blkid /dev/sdd1 | grep -oP 'UUID="\K[^"]+'
```

Backup and edit fstab:

```bash
sudo cp /etc/fstab /etc/fstab.backup
```

Add this line to `/etc/fstab` (replace UUID and filesystem type):

```
UUID=<YOUR-UUID>  /mnt/WaRlOrD  ext4  defaults,nofail  0  2
```

Test the entry:

```bash
sudo umount /mnt/WaRlOrD
sudo mount -a
df -h /mnt/WaRlOrD
```

> The `nofail` option prevents boot failure if the drive is disconnected.

### 1.4 Create Directory Structure

```bash
sudo mkdir -p /mnt/WaRlOrD/{admin-vault,shared,media}
```

## Phase 2: Create Groups and Users

### 2.1 Create Linux Groups

Three groups map to three access tiers:

```bash
sudo groupadd samba-admins
sudo groupadd samba-standard
sudo groupadd samba-guests
```

### 2.2 Create and Assign Users

```bash
# Admin user — add to both admin and standard groups
sudo usermod -aG samba-admins <admin-username>
sudo usermod -aG samba-standard <admin-username>

# Standard user — no shell login needed
sudo useradd -m -s /bin/nologin <standard-username>
sudo usermod -aG samba-standard <standard-username>

# Guest user — no shell login needed
sudo useradd -m -s /bin/nologin <guest-username>
sudo usermod -aG samba-guests <guest-username>
```

> Using `/bin/nologin` as the shell prevents these users from logging into the server via SSH. They can only access Samba shares.

### 2.3 Add Users to Samba Database

```bash
# Add each user (you'll be prompted to set a Samba password)
sudo smbpasswd -a <admin-username>
sudo smbpasswd -a <standard-username>
sudo smbpasswd -a <guest-username>

# Enable the users
sudo smbpasswd -e <admin-username>
sudo smbpasswd -e <standard-username>
sudo smbpasswd -e <guest-username>

# Verify
sudo pdbedit -L
```

### 2.4 Set Directory Permissions

```bash
# Admin vault — only samba-admins can access
sudo chown root:samba-admins /mnt/WaRlOrD/admin-vault
sudo chmod 2770 /mnt/WaRlOrD/admin-vault

# Shared storage — admins and standard users
sudo chown root:samba-standard /mnt/WaRlOrD/shared
sudo chmod 2775 /mnt/WaRlOrD/shared

# Media library — everyone can read, admins/standard can write
sudo chown root:samba-standard /mnt/WaRlOrD/media
sudo chmod 2775 /mnt/WaRlOrD/media
```

> The `2` prefix (setgid bit) ensures new files inherit the directory's group. See the [Permission Model](permission-model.md) doc for details.

## Phase 3: Configure Samba

### 3.1 Backup Existing Config

```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

### 3.2 Apply Configuration

Copy the template and edit:

```bash
sudo cp configs/samba/smb.conf.template /etc/samba/smb.conf
sudo nano /etc/samba/smb.conf
```

See [`configs/samba/smb.conf.template`](../configs/samba/smb.conf.template) for the full annotated configuration.

Key settings:

| Setting | Value | Why |
|---------|-------|-----|
| `security = user` | User-level auth | Each client authenticates with Samba credentials |
| `map to guest = never` | Disabled | Prevents anonymous access |
| `min protocol = SMB2` | SMB2 minimum | Blocks insecure SMB1 connections |
| `valid users = @group` | Per-share | Restricts which groups can access each share |
| `force group = group` | Per-share | Ensures consistent group ownership on new files |

### 3.3 Validate and Restart

```bash
# Test config for syntax errors
testparm

# Restart Samba services
sudo systemctl restart smb nmb

# Verify services are running
sudo systemctl status smb nmb
```

## Next Steps

- [Test and validate permissions](testing-validation.md)
- [Understand the permission model](permission-model.md)
- [Design rationale for user tiers](user-tier-design.md)
