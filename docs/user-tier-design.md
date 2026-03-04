# User Tier Design

This document explains the rationale behind the 3-tier access model and how it applies the principle of least privilege.

## The Principle of Least Privilege

Every user should have only the minimum access required to perform their role. No more, no less.

In practice this means:
- A family member streaming movies doesn't need write access to admin files
- A temporary guest doesn't need to see the main shared storage
- Only system administrators should manage sensitive configurations

## The Three Tiers

### Tier 1: Admin (`samba-admins`)

**Role**: System administrators with full control.

| Attribute | Value |
|-----------|-------|
| Linux group | `samba-admins` |
| Shell access | Yes (`/bin/bash`) |
| Shares accessible | AdminVault, SharedDrive, MediaLibrary |
| Permissions | Read, Write, Delete on all shares |
| Use case | Server owner, trusted co-administrators |

Admins are also added to `samba-standard` so they can access standard-tier directories without permission issues.

### Tier 2: Standard (`samba-standard`)

**Role**: Trusted regular users with read/write access to shared files.

| Attribute | Value |
|-----------|-------|
| Linux group | `samba-standard` |
| Shell access | No (`/bin/nologin`) |
| Shares accessible | SharedDrive, MediaLibrary |
| Permissions | Read, Write, Delete on SharedDrive and MediaLibrary |
| Use case | Family members, housemates, trusted collaborators |

Standard users cannot access AdminVault. They have no SSH login — Samba is their only entry point.

### Tier 3: Guest (`samba-guests`)

**Role**: Limited users with read-only access to public media.

| Attribute | Value |
|-----------|-------|
| Linux group | `samba-guests` |
| Shell access | No (`/bin/nologin`) |
| Shares accessible | MediaLibrary (read-only) |
| Permissions | Read only on MediaLibrary |
| Use case | Visitors, temporary access, media streaming devices |

Guests cannot write, delete, or even see AdminVault or SharedDrive.

## Mapping: Groups → Directories → Shares

```
samba-admins
  └── /mnt/WaRlOrD/admin-vault  (2770)  → [AdminVault]  R/W/D
  └── /mnt/WaRlOrD/shared       (2775)  → [SharedDrive]  R/W/D
  └── /mnt/WaRlOrD/media        (2775)  → [MediaLibrary] R/W/D

samba-standard
  └── /mnt/WaRlOrD/shared       (2775)  → [SharedDrive]  R/W/D
  └── /mnt/WaRlOrD/media        (2775)  → [MediaLibrary] R/W/D

samba-guests
  └── /mnt/WaRlOrD/media        (2775)  → [MediaLibrary] R (read-only, enforced by Samba read list)
```


**If you need more granularity**, POSIX ACLs can add per-user exceptions without creating new tiers. See the [Permission Model](permission-model.md) doc.

## Security Boundaries

Each tier boundary is enforced at multiple layers:

| Layer | How It's Enforced |
|-------|-------------------|
| Linux groups | Users belong to one group — access follows group membership |
| Directory permissions | `chmod` restricts who can read/write/enter each directory |
| Setgid | New files inherit the directory group, preventing permission drift |
| Samba `valid users` | Only specified groups can connect to each share |
| Samba `write list` / `read list` | Controls write vs read-only access per share |
| Shell restriction | Non-admin users have `/bin/nologin` — no SSH, no shell escape |

This layered approach means a single misconfiguration at one layer doesn't grant full access — other layers still enforce boundaries.

## Adding Custom Tiers

If your use case needs a fourth tier (e.g., a "contributor" who can write to MediaLibrary but not SharedDrive):

1. Create a new group: `sudo groupadd samba-contributors`
2. Create a directory or reuse an existing one with appropriate permissions
3. Add a new `[Share]` block in `smb.conf` with `valid users = @samba-contributors`
4. Optionally add POSIX ACLs for filesystem-level enforcement
