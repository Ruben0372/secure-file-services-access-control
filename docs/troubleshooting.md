# Troubleshooting

Real issues encountered during this project and how they were resolved, plus a general troubleshooting checklist.

## Real Debug Report: Permission Denied on CIFS Mount

### The Problem

User `rhude667` was getting "permission denied" errors when trying to write to the shared drive mounted at `/home/rhude667/theShare`.

### Investigation

```bash
$ mount | grep theShare
//host-ip/SharedDrive on /home/rhude667/theShare type cifs
  (rw,relatime,vers=3.1.1,cache=strict,username=rhude667,uid=0,gid=0,...)
```

```bash
$ ls -la /home/rhude667/theShare
-rwxr-xr-x  1 root root  ...  file1.txt
drwxr-xr-x  2 root root  ...  documents/
```

### Root Cause

The CIFS mount was using `uid=0,gid=0` (root) instead of the user's actual UID/GID (1000). Every file appeared owned by root, so user `rhude667` only had "other" permissions (read + execute, no write).

### The Fix

**Temporary** — remount with correct UID/GID:

```bash
sudo umount /home/rhude667/theShare
sudo mount -t cifs //host-ip/SharedDrive /home/rhude667/theShare \
  -o username=rhude667,uid=1000,gid=1000,file_mode=0755,dir_mode=0755
```

**Permanent** — update `/etc/fstab`:

```
//host-ip/SharedDrive /home/rhude667/theShare cifs username=rhude667,uid=1000,gid=1000,file_mode=0755,dir_mode=0755,credentials=/home/rhude667/.smbcreds 0 0
```

**Credentials secured** — moved password out of fstab:

```bash
echo "username=rhude667" > ~/.smbcreds
echo "password=<your-password>" >> ~/.smbcreds
chmod 600 ~/.smbcreds
```

### Takeaway

CIFS mounts default to root ownership. Always specify `uid` and `gid` matching the intended user.

---

## Issues Found During Initial Setup

### 1. Invalid Samba Parameter: `valid user` (singular)

**Symptom**: Share accessible to unintended users or not working at all.

**Cause**: Using `valid user` instead of `valid users` (plural). Samba silently ignores the invalid parameter.

**Fix**: Always use `valid users` (plural) in `smb.conf`:

```ini
# Wrong
valid user = @samba-admins

# Correct
valid users = @samba-admins
```

**Lesson**: Run `testparm` after every config change — it reports unknown parameters.

### 2. Missing `[global]` Section Order

**Symptom**: Global settings not applied, shares behaving with default settings.

**Cause**: Share definitions `[ShareName]` were placed before the `[global]` section in `smb.conf`.

**Fix**: `[global]` must always be the first section in the file.

### 3. Drive Not Mounted

**Symptom**: Shares appear empty, users can connect but see no files.

**Cause**: The storage drive was not mounted at `/mnt/WaRlOrD`.

**Fix**: Mount the drive and add to fstab with `nofail` option.

```bash
# Check if mounted
df -h /mnt/WaRlOrD

# If empty, mount it
sudo mount -a
```

### 4. Directory Owned by Root

**Symptom**: "Permission denied" when creating files through Samba.

**Cause**: Directory group ownership was `root` instead of the Samba group.

**Fix**:

```bash
sudo chown root:samba-standard /mnt/WaRlOrD/shared
sudo chmod 2775 /mnt/WaRlOrD/shared
```

---

## General Troubleshooting Checklist

| Symptom | What to Check | Command |
|---------|---------------|---------|
| Share not visible | Samba config syntax | `testparm` |
| Can't connect to share | Samba service running | `sudo systemctl status smb nmb` |
| "Permission denied" | Group membership | `groups <username>` |
| "Permission denied" | Directory ownership | `ls -ld /mnt/WaRlOrD/<dir>` |
| "Permission denied" | Samba user exists | `sudo pdbedit -L` |
| Files owned by wrong group | Setgid bit missing | `ls -ld /mnt/WaRlOrD/<dir>` (look for `s`) |
| Can't write (guest) | Expected — read-only tier | Check `read list` in smb.conf |
| Slow performance | Samba tuning settings | Check `aio` and `sendfile` in smb.conf |
| Share empty | Drive not mounted | `df -h /mnt/WaRlOrD` |

## Useful Diagnostic Commands

```bash
# Samba status and connected users
sudo smbstatus

# List all Samba users
sudo pdbedit -L -v

# Test config file
testparm

# View Samba logs
sudo tail -f /var/log/samba/log.*

# Check group membership for a user
groups <username>
id <username>

# Check directory permissions and ownership
ls -ld /mnt/WaRlOrD/*

# Check if setgid is set
stat /mnt/WaRlOrD/shared

# View POSIX ACLs
getfacl /mnt/WaRlOrD/shared
```
