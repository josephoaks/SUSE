# SELinux Policy – tpi_exec Enforcement Module

Purpose: Enforce that all privileged 389-DS and system management commands are executed only through the tpi_exec wrapper, and isolate that domain from direct execution attempts.

## Overview

The tpi_exec SELinux policy creates a controlled domain that enforces Two-Person-Integrity (TPI) at the kernel level.

This policy ensures:

* Only /usr/local/sbin/tpi_exec can execute certain administrative commands (systemctl, dsconf, dsctl, ns-slapd, etc.).
* No other domain (including user_t, staff_t, or unconfined_t) can execute those binaries directly.
* All audit events are logged and denials are traceable via ausearch.

## File Structure

<pre>
selinux/
├── tpi_exec.te    ← SELinux type enforcement policy
└── tpi_exec.fc    ← File context definitions
</pre>

### Policy Source Files
1. tpi_exec.te
2. tpi_exec.fc

***These are just examples, and should be modified to the endusers needs! ! !***

## Building and Installing the Policy

All commands are run as root or under sudo.

Make the `tpi_exec` directory and copy these files to the SELinux Policy Directory they will be executed when the setup script runs.

```bash
`mkdir /usr/share/selinux/packages/tpi_exec`
`/usr/share/selinux/packages/tpi_exec`
```

## Summary

* SELinux module defines tpi_exec_t domain for all privileged actions.
* Only the wrapper can enter that domain.
* Unauthorized direct execution is denied.
* Fully auditable through the kernel’s security policy.
