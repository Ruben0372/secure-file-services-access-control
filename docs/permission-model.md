# Permission Model Deep Dive

This document explains the Linux permission concepts I used in this project, from basic file permissions to POSIX ACLs.

## Standard Linux Permissions

### The Basics

Every file and directory has three permission sets:

```
  Owner   Group   Other
  r w x   r w x   r w x
```

| Symbol | Meaning | On Files | On Directories |
|--------|---------|----------|----------------|
| `r` (4) | Read | View contents | List files |
| `w` (2) | Write | Modify contents | Create/delete files inside |
| `x` (1) | Execute | Run as program | Enter (cd into) directory |

### Numeric Notation

Permissions are represented as 3-digit octal numbers. Each digit is the sum of its permission values:

```
rwx = 4+2+1 = 7    (full access)
rw- = 4+2+0 = 6    (read + write)
r-x = 4+0+1 = 5    (read + execute)
r-- = 4+0+0 = 4    (read only)
--- = 0+0+0 = 0    (no access)
```

### How This Project Uses Them

```
admin-vault:  2770  →  rwxrwx---  →  owner + group: full, others: nothing
shared:       2775  →  rwxrwxr-x  →  owner + group: full, others: read/enter
media:        2775  →  rwxrwxr-x  →  owner + group: full, others: read/enter
```

## The Setgid Bit

### The Problem It Solves

Without setgid, when a user creates a file in a shared directory, the file's group is set to the user's primary group — not the directory's group. This breaks shared access:

```bash
# Without setgid
$ touch /mnt/WaRlOrD/shared/report.txt
$ ls -l /mnt/WaRlOrD/shared/report.txt
-rw-r--r-- 1 alice alice 0 ...    # group is "alice", not "samba-standard"
```

Other members of `samba-standard` may not be able to modify this file.

### How Setgid Fixes It

Setting the setgid bit (the `2` prefix) on a directory forces all new files to inherit the directory's group:

```bash
# Set setgid
sudo chmod 2775 /mnt/WaRlOrD/shared

# Now when alice creates a file:
$ touch /mnt/WaRlOrD/shared/report.txt
$ ls -l /mnt/WaRlOrD/shared/report.txt
-rw-r--r-- 1 alice samba-standard 0 ...    # group inherited from directory
```

### Verify Setgid

The setgid bit shows as `s` in the group execute position:

```bash
$ ls -ld /mnt/WaRlOrD/shared
drwxrwsr-x 2 root samba-standard 4096 ... shared
#      ^ 's' here means setgid is active
```

## POSIX ACLs

Standard permissions (owner/group/other) only support one group per file. POSIX ACLs extend this when you need more granular control.

### When to Use ACLs vs Standard Permissions

| Scenario | Use |
|----------|-----|
| One group needs access to a directory | Standard permissions |
| Multiple groups need different access levels to the same directory | POSIX ACLs |
| You need per-user exceptions | POSIX ACLs |
| Simple share setup | Standard permissions |

### ACL Commands

```bash
# View ACLs on a file/directory
getfacl /mnt/WaRlOrD/shared

# Grant a specific group read access
sudo setfacl -m g:samba-guests:r-x /mnt/WaRlOrD/media

# Grant a specific user write access
sudo setfacl -m u:alice:rwx /mnt/WaRlOrD/shared/project-alpha

# Set default ACL (applies to new files created inside)
sudo setfacl -d -m g:samba-standard:rwx /mnt/WaRlOrD/shared

# Remove an ACL entry
sudo setfacl -x g:samba-guests /mnt/WaRlOrD/media

# Remove all ACLs
sudo setfacl -b /mnt/WaRlOrD/shared
```

### Example: Giving Guests Read Access to Media

Instead of relying only on Samba's `read list`, you can enforce it at the filesystem level:

```bash
# Set ACL so samba-guests can read but not write
sudo setfacl -R -m g:samba-guests:r-x /mnt/WaRlOrD/media

# Set default ACL so new files also get this rule
sudo setfacl -R -d -m g:samba-guests:r-x /mnt/WaRlOrD/media

# Verify
getfacl /mnt/WaRlOrD/media
```

Output:

```
# file: mnt/WaRlOrD/media
# owner: root
# group: samba-standard
# flags: -s-
user::rwx
group::rwx
group:samba-guests:r-x
mask::rwx
other::r-x
```

## How Samba and Linux Permissions Interact

Samba enforces access at two layers:

1. **Samba layer** — `valid users`, `write list`, `read list` in `smb.conf`
2. **Filesystem layer** — Linux permissions (chmod/chown/ACLs)

**Both layers must allow access.** If Samba grants write access but the filesystem doesn't, the write will fail. This is defense in depth, even if Samba is misconfigured, the filesystem permissions act as a safety net.

```
Client Request → Samba Auth → Samba Share ACL → Linux Filesystem Permissions → Allow/Deny
```

## Summary

| Concept | What It Does | Used In This Project |
|---------|-------------|---------------------|
| chmod | Set basic permissions (rwx) | All share directories |
| chown | Set owner and group | All share directories |
| Setgid (2xxx) | New files inherit directory group | All share directories |
| POSIX ACLs | Fine-grained per-user/group rules | Optional, for advanced scenarios |
