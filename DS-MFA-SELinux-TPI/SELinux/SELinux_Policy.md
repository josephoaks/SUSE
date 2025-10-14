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
├── tpi_exec.fc    ← File context definitions
└── tpi_exec.if    ← Interface (optional, used if extending)
</pre>

⚙️ 2️⃣ Policy Source Files
a) tpi_exec.te

b) tpi_exec.fc
/usr/local/sbin/tpi_exec         --      system_u:object_r:tpi_exec_exec_t:s0
/usr/sbin/dsconf                 --      system_u:object_r:dsconf_exec_t:s0
/usr/sbin/dsctl                  --      system_u:object_r:dsctl_exec_t:s0
/usr/sbin/ns-slapd               --      system_u:object_r:ns_slapd_exec_t:s0

c) tpi_exec.if (optional, for future extension)
interface(`tpi_exec_domtrans',`
    gen_require(`
        type tpi_exec_exec_t, tpi_exec_t;
    ')
    domain_auto_trans($1, tpi_exec_exec_t, tpi_exec_t)
')

interface(`tpi_exec_allow_admin_tools',`
    gen_require(`
        type tpi_exec_t;
        type systemctl_exec_t, dsconf_exec_t, dsctl_exec_t, ns_slapd_exec_t;
    ')
    allow tpi_exec_t systemctl_exec_t:file { read open execute getattr };
    allow tpi_exec_t dsconf_exec_t:file { read open execute getattr };
    allow tpi_exec_t dsctl_exec_t:file  { read open execute getattr };
    allow tpi_exec_t ns_slapd_exec_t:file { read open execute getattr };
')

🛠️ 3️⃣ Building and Installing the Policy

All commands are run as root or under sudo.

Step 1: Check for SELinux tools
zypper in policycoreutils selinux-tools checkpolicy
# or
dnf install policycoreutils checkpolicy selinux-policy-devel

Step 2: Build the module
cd /path/to/selinux
checkmodule -M -m -o tpi_exec.mod tpi_exec.te
semodule_package -o tpi_exec.pp -m tpi_exec.mod -f tpi_exec.fc

Step 3: Install the module
semodule -i tpi_exec.pp


Confirm installation:

semodule -l | grep tpi_exec
# tpi_exec  1.0

🧾 4️⃣ Labeling the Files

Label the TPI wrapper and related binaries:

semanage fcontext -a -t tpi_exec_exec_t "/usr/local/sbin/tpi_exec"
restorecon -v /usr/local/sbin/tpi_exec


You can verify context:

ls -Z /usr/local/sbin/tpi_exec
# system_u:object_r:tpi_exec_exec_t:s0 /usr/local/sbin/tpi_exec

🧰 5️⃣ Verification
Step 1: Run a permitted command
sudo tpi_exec systemctl status dirsrv@ds01


✅ Should execute normally.

Step 2: Try bypassing TPI
sudo systemctl restart dirsrv@ds01


❌ Should fail with SELinux denial logged.

Check audit:

ausearch -m avc -ts recent | grep systemctl


Example log:

avc:  denied  { execute } for pid=1423 comm="sudo" name="systemctl"
dev="dm-0" ino=1234567 scontext=user_u:user_r:user_t:s0 tcontext=system_u:object_r:systemctl_exec_t:s0 tclass=file

🧪 6️⃣ Troubleshooting
Symptom	Likely Cause	Resolution
tpi_exec denied executing systemctl	Missing allow rule	Rebuild module after adding allow line
Permission denied on log file	Label mismatch	restorecon -v /var/log/tpi_exec.log
tpi_exec_t not visible in ps -Z	No domain transition	Check domain_auto_trans() rule
SELinux in permissive mode	Enforcement disabled	setenforce 1
🧱 7️⃣ Removing or Updating the Module

To remove:

semodule -r tpi_exec


To replace with an updated version:

semodule -i tpi_exec.pp


To view module content:

semodule -l | grep tpi_exec
sesearch -A -s tpi_exec_t

🔒 8️⃣ Security Model Summary
Aspect	Enforcement
Domain Isolation	Only tpi_exec_t may call DS/systemctl executables
File Labeling	/usr/local/sbin/tpi_exec labeled tpi_exec_exec_t
Transition Control	user_t → tpi_exec_exec_t → tpi_exec_t
Audit Visibility	Every bypass attempt logged in auditd
Hard Bypass Prevention	Disallows direct invocation of privileged binaries even with root sudo access
🧩 9️⃣ Optional Hardening

To further lock down access:

setsebool -P domain_can_exec_all 0
setsebool -P selinuxuser_execheap 0


Restrict tpi_exec_t to local logs only:

allow tpi_exec_t var_log_t:file append;
dontaudit tpi_exec_t user_home_t:file write;

✅ Summary

SELinux module defines tpi_exec_t domain for all privileged actions.

Only the wrapper can enter that domain.

Unauthorized direct execution is denied.

Fully auditable through the kernel’s security policy.
