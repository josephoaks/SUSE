# SLES 15 SP6 Secure Configuration & Compliance Guide

## 1. Prerequisite Package Installation
To ensure the system has all required tools for FIPS enablement, repository management, and STIG scanning, install all necessary packages in one consolidated step.

```bash
zypper in -y patterns-base-fips \
              crypto-policies-scripts \
              rmt-server \
              createrepo_c \
              nginx \
              scap-security-guide \
              openscap-utils
```
              
Packages Included:
* patterns-base-fips – Required kernel modules and libraries for FIPS.
* crypto-policies-scripts – Manages system crypto policies.
* rmt-server – Repository Mirroring Tool for air‑gapped updates.
* createrepo_c – Generates repository metadata for local RPM repos.
* nginx – Lightweight web server to host local repositories.
* scap-security-guide & openscap-utils – Tools and content for STIG scanning and remediation.

## 2. FIPS Mode Enablement
### 2.1 Enable FIPS
```bash
fips-mode-setup --enable
```
This:
* Adds fips=1 to the kernel command line.
* Rebuilds the initramfs with FIPS modules.

### 2.2 Reboot System
```bash
reboot
```

### 2.3 Verify FIPS Mode
```bash
fips-mode-setup --check
```
Expected output:

```bash
FIPS mode is enabled.
Initramfs fips module is enabled.
The current crypto policy (FIPS) is based on the FIPS policy.
Optional kernel check:
```

```bash
cat /proc/sys/crypto/fips_enabled
```
Should return: 1

## 3. RMT (Repository Mirroring Tool) Setup
This step prepares the system for updates.

### 3.1 Configure RMT Server
Run `yast` and got to `Network Services` -> `RMT Configuration`

* input organization credentials
* complete setup with passwords for the database and ssl certificate

When done exit `yast` and finish the setup of the repos

### 3.2 Enable products for mirroring
```bash
rmt-cli sync
rmt-cli products list --all | grep -i micro | grep 5.3
rmt-cli products enable <product id>
rmt-cli mirror
```

RMT will serve SUSE repositories at:
```bash
http://<server-ip>/repo/
```

## 4. Custom Local Repository Setup

### 4.1 Create Repository Structure and copy custom rpms into the newly create repo

```bash
mkdir -p /srv/www/htdocs/repos/custom/
cp /path/to/*.rpm /srv/www/htdocs/repos/custom/
createrepo /srv/www/htdocs/repos/custom/
chmod -R 755 /srv/www/htdocs/repos
```

### 4.2 Configure Nginx to Serve Repos
Edit /etc/nginx/nginx.conf and confirm this location block exists:
```bash
location ^~ /repos/ {
    root /srv/www/htdocs/;
    autoindex on;
}
```

Reload Nginx:
```bash
nginx -t
systemctl restart nginx
```

### 4.3 Verify Repo Access
```bash
curl http://localhost/repos/custom/repodata/repomd.xml
```
You should see XML output confirming repo metadata.

### 4.4 Add Repo to Zypper
Create /etc/zypp/repos.d/custom.repo:
```bash
[custom-local]
name=Custom Local Repo
enabled=1
autorefresh=0
baseurl=http://localhost/repos/custom/
gpgcheck=0
```

Refresh repos:
```bash
zypper ref
```

## 5. STIG Scanning and Remediation

### 5.1 Dry-Run STIG Scan
```bash
oscap xccdf eval \
  --profile stig \
  --results /tmp/ssg-results.xml \
  --report /tmp/ssg-report.html \
  /usr/share/xml/scap/ssg/content/ssg-sle15-ds.xml
```
This generates:
* /tmp/ssg-results.xml (machine-readable results)
* /tmp/ssg-report.html (human-readable compliance report)

### 5.2 Full Remediation Command
```bash
oscap xccdf eval \
  --profile stig \
  --results /tmp/ssg-results.xml \
  --report /tmp/ssg-report.html \
  --remediate \
  /usr/share/xml/scap/ssg/content/ssg-sle15-ds.xml
```
Notes:
* --remediate automatically applies all automatable STIG fixes.
* Manual actions may still be required for some controls (documented in the report).

## 6. Validation & Compliance Reporting
Confirm FIPS remains active:
```bash
fips-mode-setup --check
```

Verify custom repo access:
```bash
zypper se <package-name>
```
## *** CRITICAL ***

Reset user passwords
```bash
password <user_name>
```

Review the OpenSCAP HTML report (/tmp/ssg-report.html) and attach to compliance documentation.

### Reboot 

```bash
reboot
```

## Conclusion
This guide provides:

* Verified FIPS Mode (federal requirement for cryptographic operations)
* Disconnected RMT for air‑gapped environments
* Custom Local Repository served via Nginx
* STIG Scan and Automated Remediation using OpenSCAP

All steps are repeatable, auditable, and ready for submission as part of a federal compliance package.
