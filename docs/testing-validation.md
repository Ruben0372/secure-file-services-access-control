# Testing & Validation

How to verify every permission boundary is correctly enforced after setup.

## Prerequisites

- Samba is running: `sudo systemctl status smb nmb`
- Config is valid: `testparm`
- At least one user per tier exists: `sudo pdbedit -L`

## Test 1: List Available Shares

```bash
smbclient -L localhost -U <admin-username>
```

**Expected**: You should see AdminVault, SharedDrive, and MediaLibrary listed.

## Test 2: Admin Access

Admin users should have full access to all three shares.

```bash
# Connect to AdminVault
smbclient //localhost/AdminVault -U <admin-username>

# Inside the smbclient prompt, test write:
smb: \> put /tmp/test-admin.txt test-admin.txt
smb: \> ls
smb: \> del test-admin.txt
smb: \> quit
```

```bash
# Connect to SharedDrive
smbclient //localhost/SharedDrive -U <admin-username>

# Test write
smb: \> put /tmp/test-admin.txt test-admin.txt
smb: \> del test-admin.txt
smb: \> quit
```

```bash
# Connect to MediaLibrary
smbclient //localhost/MediaLibrary -U <admin-username>

# Test write
smb: \> put /tmp/test-admin.txt test-admin.txt
smb: \> del test-admin.txt
smb: \> quit
```

**Expected**: All operations succeed.

## Test 3: Standard User Access

Standard users should access SharedDrive and MediaLibrary but NOT AdminVault.

```bash
# This should FAIL — standard user cannot access AdminVault
smbclient //localhost/AdminVault -U <standard-username>
```

**Expected**: `NT_STATUS_ACCESS_DENIED` or connection refused.

```bash
# This should SUCCEED
smbclient //localhost/SharedDrive -U <standard-username>

smb: \> put /tmp/test-standard.txt test-standard.txt
smb: \> ls
smb: \> del test-standard.txt
smb: \> quit
```

**Expected**: Read and write succeed.

## Test 4: Guest Access

Guest users should only read MediaLibrary. No access to AdminVault or SharedDrive.

```bash
# This should FAIL
smbclient //localhost/AdminVault -U <guest-username>
```

**Expected**: `NT_STATUS_ACCESS_DENIED`

```bash
# This should FAIL
smbclient //localhost/SharedDrive -U <guest-username>
```

**Expected**: `NT_STATUS_ACCESS_DENIED`

```bash
# This should SUCCEED (read-only)
smbclient //localhost/MediaLibrary -U <guest-username>

# List files — should work
smb: \> ls

# Try to write — should FAIL
smb: \> put /tmp/test-guest.txt test-guest.txt
```

**Expected**: `ls` succeeds, `put` fails with `NT_STATUS_ACCESS_DENIED`.

## Test 5: File Ownership Inheritance

Verify setgid is working — new files should inherit the directory group.

```bash
# As admin, create a file in SharedDrive
smbclient //localhost/SharedDrive -U <admin-username> -c "put /tmp/test-owner.txt test-owner.txt"

# Check ownership on the server
ls -l /mnt/WaRlOrD/shared/test-owner.txt
```

**Expected**: Group should be `samba-standard`, not the user's primary group.

```bash
# Clean up
rm /mnt/WaRlOrD/shared/test-owner.txt
```

## Test 6: Verify Samba Config

```bash
testparm -s
```

**Check for**:
- `security = user` is set
- `map to guest = never` is set
- `min protocol = SMB2` is set
- Each share has correct `valid users` and `write list`

## Test Summary Table

| Test | User Tier | Share | Action | Expected Result |
|------|-----------|-------|--------|-----------------|
| 2a | Admin | AdminVault | Write/Delete | PASS |
| 2b | Admin | SharedDrive | Write/Delete | PASS |
| 2c | Admin | MediaLibrary | Write/Delete | PASS |
| 3a | Standard | AdminVault | Connect | DENIED |
| 3b | Standard | SharedDrive | Write/Delete | PASS |
| 4a | Guest | AdminVault | Connect | DENIED |
| 4b | Guest | SharedDrive | Connect | DENIED |
| 4c | Guest | MediaLibrary | Read | PASS |
| 4d | Guest | MediaLibrary | Write | DENIED |
| 5 | Admin | SharedDrive | Create file | Group = samba-standard |

If any test produces an unexpected result, see the [Troubleshooting](troubleshooting.md) doc.
