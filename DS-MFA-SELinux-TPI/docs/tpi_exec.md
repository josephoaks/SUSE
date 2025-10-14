# `tpi_exec` – Two-Person Integrity Enforcement Wrapper

Path: /usr/local/sbin/tpi_exec
Purpose: Enforce Two-Person Integrity (TPI) for critical operations such as restarting Directory Services, databases, or other sensitive daemons.
Applies to: Environments with DS + MFA + SELinux enforcement.

## Overview

The `tpi_exec` script enforces that no single user can execute certain privileged operations without a second approval.

It works by requiring:

* A first authorized user to initiate an operation.
* A second authorized user to re-issue the same command within a short time window (default: 5 minutes).

Only after the second approval does the command actually execute.

This script integrates directly with:

* SELinux policy enforcement (tpi_exec_t)
* sudoers command restrictions
* MFA/YubiKey authentication
* 389-DS / systemd / administrative scripts

## How It Works

| Phase | Description |
| ----- | ----------- |
| First invocation | User A runs tpi_exec <command>. Script records their username and timestamp in /var/lock/tpi_action.lock and exits. |
| Second invocation | User B runs the same tpi_exec <command> within 300 seconds. Script detects existing lock file and executes the command. |
| Timeout cleanup | If the second approval never occurs, the lock file is deleted after the timeout period (default = 300 s = 5 min). |

## Security Concepts

| Mechanism | Purpose |
| --------- | ------- |
| Lock file | Guarantees a pending approval state that only persists briefly. |
| Timeout thread | Prevents stale approval requests from remaining valid indefinitely. |
| SELinux domain (tpi_exec_t) | Restricts this wrapper to execute only approved administrative commands (see SELinux Policy). |
sudoers binding | Only users in specific groups (e.g. tpi_approvers, dsadmins) may run /usr/local/sbin/tpi_exec. |
| MFA/YubiKey login | Ensures each approver is physically authenticated. |

## Directory and Permissions

```bash
install -m 750 tpi_exec /usr/local/sbin/tpi_exec
chown root:tpi /usr/local/sbin/tpi_exec
mkdir -p /var/lock
chmod 1777 /var/lock
```

## Example Usage
Restart Directory Server
`sudo /usr/local/sbin/tpi_exec systemctl restart dirsrv@ds01`

Expected Output (first user)
```pgsql
[TPI] 2025-10-13 15:41:12: First approver recorded for 'systemctl restart dirsrv@ds01'
Run again within 300 seconds (by another authorized user) to execute.
Lock file: /var/lock/tpi_action.lock
```

Expected Output (second user)
```pgsql
[TPI] 2025-10-13 15:42:37: Second authorization detected. Executing: systemctl restart dirsrv@ds01
```

## Logging and Auditing

By default, the script logs to stdout and audit messages appear via:

* `/var/log/secure` (through sudo)
* `/var/log/audit/audit.log` (via SELinux AVCs)
* Custom `/var/log/tpi_exec.log` (optional)

To add persistent logging, extend with:

`echo "[TPI] $(timestamp): $USER executed $CMD" >> /var/log/tpi_exec.log`

## Integration with sudoers

Example /etc/sudoers.d/tpi_exec:

```bash
# Two-Person Integrity enforcement for critical operations
Cmnd_Alias TPI_CMDS = /usr/local/sbin/tpi_exec *

%tpi_approvers ALL=(root) NOPASSWD: TPI_CMDS
Defaults!/usr/local/sbin/tpi_exec !authenticate
```

This ensures:

* Only members of tpi_approvers can execute it.
* Direct execution of the underlying commands (like systemctl) is still denied by SELinux.

## SELinux Enforcement

The SELinux module defines:

* `tpi_exec_exec_t` – file context for `/usr/local/sbin/tpi_exec`
* `tpi_exec_t` – runtime domain for approved commands

Policy ensures:

* `user_t` cannot execute systemctl/dsctl directly.
* Only transitions from `user_t` → `tpi_exec_exec_t` → `tpi_exec_t` are allowed.

## Configuration Variables

| Variable | Description	| Default |
| -------- | ---------- | ------- |
| `LOCKFILE` | Path to approval record file | `/var/lock/tpi_action.lock` |
| `TIMEOUT` | Approval window in seconds | `300` |
| `CMD` | Command to execute | Inherited from user input |
| `timestamp()` | Time function | Returns `YYYY-MM-DD HH:MM:SS` |

You can modify these safely to match organizational policy:

* Shorter timeouts for higher-sensitivity systems.
* Multiple lock files (e.g. /var/lock/tpi_action_$HASH.lock) for parallel operations.

## Advanced Enhancements (Optional)
| Feature | Description |
| ------- | ----------- |
| User verification | Parse `/etc/group` or LDAP to ensure User A ≠ User B. |
| Command whitelist | Allow only pre-approved executables (e.g. `systemctl`, `dsctl`, `ipa-server-upgrade`). |
| Audit trail | Log all attempts (success and timeout) with usernames and timestamps. |
| Notification | Send email or webhook when first approver initiates an action. |
| Extended SELinux types | Add `tpi_exec_log_t` to segregate its log file. |


## Example Hardening

You can enforce that the first and second user must differ:

```bash
if [ -f "$LOCKFILE" ]; then
    FIRST_USER=$(cut -d' ' -f1 "$LOCKFILE")
    if [ "$FIRST_USER" = "$USER" ]; then
        echo "[TPI] Same user cannot self-approve. Action denied."
        exit 1
    fi
fi
```

This ensures true two-person integrity.

## Troubleshooting

| Problem | Likely Cause | Resolution |
| ------- | ------------ | ---------- |
| “Timeout expired” | Second user missed 5 min window | Rerun first step |
| Command executes immediately | SELinux not enforcing | setenforce 1 |
| “Permission denied” | Wrong file permissions on /usr/local/sbin/tpi_exec | Fix mode to 750 |
| First user prompt never clears | Background cleanup thread failed | Verify shell supports disown or use nohup |
| No audit entries | Auditd not running | systemctl enable --now auditd |


## Summary

* `tpi_exec` adds an operational 2-person integrity check for any root-level command.
* Works alongside MFA, sudoers, and SELinux for a layered defense model.
* All executions are logged, auditable, and time-bound.
* Prevents single-user compromise from affecting critical systems.
