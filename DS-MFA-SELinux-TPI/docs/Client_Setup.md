# Client Setup – YubiKey for SSH and PAM-U2F Authentication

- [macOS / Linux](#macos--linux)
- [Windows](#windows)

---

## macOS / Linux

Path: mfa/yubikey/Client_Setup_YubiKey.md
Purpose: Configure a client system (macOS or Linux) to use a YubiKey with a PIN and touch verification for SSH (FIDO2) and PAM-U2F authentication to a secure TPI-enforced server.

### Overview

This guide sets up:

* FIDO2-based SSH authentication (ed25519-sk keys)
* PIN-protected YubiKey for MFA
* Optional PAM-U2F for local sudo or login
* Touch-to-confirm every authentication
* Compatible with TPI + DS enforcement on the remote server

### Requirements

| Component	| macOS |	Linux |
| --------- | ----- | ----- |
| YubiKey 5 Series (with FIDO2) |	✅	| ✅ |
| libfido2 library	| Homebrew	| native pkg |
| OpenSSH ≥ 8.2	| Homebrew	| native pkg |
| Admin privileges	| required	| required |

### macOS Environment Setup

Install dependencies
```bash
brew install openssh libfido2
```

Make sure to use the Homebrew version (not Apple’s system SSH):

```bash
brew unlink openssh && brew link --overwrite openssh
which ssh
# /usr/local/bin/ssh
ssh -V
# OpenSSH_10.2p1, OpenSSL 3.x.x
```

### Verify and Configure the YubiKey

List your YubiKey
`ykman list`

Output example:
```text
YubiKey 5C Nano (5.4.3) [OTP+FIDO+CCID] Serial: 26332552
```

Show details
`ykman info`

Confirm FIDO2 is enabled:

```text
Applications:
  Yubico OTP  	Enabled
  FIDO U2F    	Enabled
  FIDO2       	Enabled
  OATH        	Enabled
  PIV         	Enabled
  OpenPGP     	Enabled
  YubiHSM Auth	Enabled
```

If not, enable it:

`ykman config usb --enable FIDO2`

### Set or Change a YubiKey PIN

You must have a PIN for FIDO2 key generation.
The PIN protects against unauthorized key use.

To set a new PIN
`ykman fido access change-pin`

Follow the prompt:

```text
Set a new PIN:
Confirm the new PIN:
```

To verify remaining attempts
`ykman fido access info`

Output example:

```text
PIN:                7 attempt(s) remaining
Minimum PIN length: 4
```

### Generate a PIN-Protected FIDO2 SSH Key
`ssh-keygen -t ed25519-sk -C "<username>@yubikey"`

Expected interaction:
```text
You may need to touch your authenticator to authorize key generation.
Enter PIN for authenticator: ****


Touch your YubiKey when prompted.
```

Result:
```text
Your identification has been saved in /Users/username/.ssh/id_ed25519_sk
Your public key has been saved in /Users/username/.ssh/id_ed25519_sk.pub
```

Check:
```bash
ssh-keygen -lf ~/.ssh/id_ed25519_sk.pub
# 256 SHA256:xxxx <username>@yubikey (ED25519-SK)
```

The -SK suffix confirms this key is bound to your YubiKey.

### Deploy Key to the Server

If SSH connectivity works:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub username@server.fqdn.com
```

Otherwise, copy manually:

```bash
cat ~/.ssh/id_ed25519_sk.pub
```

Then on the server:

```bash
mkdir -p ~/.ssh
echo "<copied line>" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

### Test YubiKey Authentication with PIN + Touch
`ssh -v username@server.fqdn.com`


Expected sequence:

```text
You may need to touch your authenticator to authorize
Enter PIN for authenticator: ****
Authenticated using "sk-ssh-ed25519@openssh.com"
```

Successful login confirms the PIN + Touch flow is active.


## Security Enhancements

| Feature	| Description |
| ------- | ----------- |
| Resident Keys	| Add `-O resident` flag to store key on YubiKey |
| Always-Touch Policy	| Enforce with: `ykman fido access set-pin-touch always` |
| Backup Key	| Register second YubiKey and store securely |
| PIN Lockout	| After 8 failed attempts, reset required (FIDO2 standard) |
| Key Reset	| `ykman fido reset` (erases all credentials) |

## Troubleshooting
| Problem |	Fix |
| `FIDO_ERR_PIN_INVALID` |	Retry with correct PIN, view remaining attempts |
| `No FIDO SecurityKeyProvider` |	Ensure /usr/local/bin/ssh from Homebrew |
| `Key ignored` |	Update sshd_config on server (see companion doc) |
| `No touch prompt` |	Enable FIDO2 with ykman config usb --enable FIDO2 |
| `Timeout` |	Reinsert YubiKey or reauthenticate PIN |

##Summary

After completion:

* YubiKey is PIN-protected
* SSH keys require both PIN + Touch
* Works with server-side TPI enforcement
* Compatible with PAM-U2F and MFA/SSO integration (Okta, Keycloak)


## Windows

Path: `mfa/yubikey/Client_Setup_Windows.md`
Purpose: Configure a Windows 10/11 workstation to use a YubiKey for FIDO2 SSH authentication (with PIN + Touch) to your secured Linux/TPI environment.

### Overview

This guide sets up your Windows workstation to:

* Use a YubiKey 5 Series (or compatible FIDO2 key)
* Authenticate to remote Linux servers over OpenSSH with FIDO2 keys
* Require PIN + Touch for every connection
* Optionally use Okta/SSO for GUI authentication (via Windows Hello)
* Integrate with your TPI + DS + MFA framework

### Prerequisites

| Component |	Requirement |
| --------- | ----------- |
| Windows 10 (2004+) or 11| 	required |
| YubiKey 5 Series| 	required |
| OpenSSH client (built-in) |	optional: Git Bash or WSL2 |
| Administrator access |	required |
| YubiKey Manager (CLI or GUI) |	recommended |

### Install YubiKey Tools

Option A: GUI (Recommended)

Download from Yubico:
https://www.yubico.com/products/services-software/download/yubikey-manager/

Install and run YubiKey Manager GUI.

Confirm device is detected and FIDO2 is enabled:

Applications:
  - OTP
  - FIDO U2F
  - FIDO2
  - PIV

Option B: CLI

Install YubiKey Manager CLI via PowerShell (requires Python):

`pip install yubikey-manager`


Verify:

```powershell
ykman list
ykman info
```

### Set or Verify YubiKey PIN

Windows may auto-register a PIN via Windows Hello the first time FIDO2 is used,
but you can explicitly set it using ykman.

To set PIN:
`ykman fido access change-pin`


or via YubiKey Manager GUI → FIDO2 → “Change PIN”.

Check remaining attempts:

`ykman fido access info`


Example:

PIN:                7 attempt(s) remaining
Minimum PIN length: 4

### Install OpenSSH with FIDO2 Support
Windows 10/11 Built-in SSH (Preferred)
```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Confirm:

```powershell
ssh -V
# OpenSSH_for_Windows_9.x, supports sk-ssh-ed25519@openssh.com
```

Optional: Git Bash or WSL2

You can alternatively use:

Git Bash (ships with modern OpenSSH)

Windows Subsystem for Linux (WSL2) for native Linux ssh tools:

sudo apt install openssh-client libfido2-1

### Generate a FIDO2 SSH Key

In PowerShell or Git Bash:

`ssh-keygen -t ed25519-sk -C "username@yubikey"`

Expected output:

```powershell
You may need to touch your authenticator to authorize key generation.
Enter PIN for authenticator: ****


Touch your YubiKey when prompted.
```

Keys are saved under:

```powershell
C:\Users\<YourUser>\.ssh\id_ed25519_sk
C:\Users\<YourUser>\.ssh\id_ed25519_sk.pub
```

### Deploy the Public Key to the Server

Option A — if network allows:

`ssh-copy-id -i $env:USERPROFILE\.ssh\id_ed25519_sk.pub username@server.fqdn.com`


Option B — manually copy:

`type $env:USERPROFILE\.ssh\id_ed25519_sk.pub`


Paste the output into:
`/home/username/.ssh/authorized_keys` on the Linux server.

### Test Connection (PIN + Touch Required)
`ssh -v username@server.fqdn.com`


Expected:

```powershell
You may need to touch your authenticator to authorize
Enter PIN for authenticator: ****
Authenticated using "sk-ssh-ed25519@openssh.com"
```

This confirms YubiKey FIDO2 authentication is working with PIN protection.


### Troubleshooting
| Issue	| Fix |
| ----- | --- |
| SSH keygen fails: `No FIDO` | SecurityKeyProvider specified	Ensure OpenSSH 9+ is installed |
| Key ignored on server	| Confirm PubkeyAuthentication yes in /etc/ssh/sshd_config |
| PIN invalid or blocked | `ykman fido reset` (resets all credentials) |
| Touch prompt never appears | Reinsert YubiKey or check FIDO2 is enabled |
| “No route to host” | Verify firewall and correct IP address |
| Using WSL but no USB access | Enable usbipd-win for YubiKey passthrough |
| Okta login works but SSH fails | Confirm matching user in LDAP/DS and authorized key present |

### Security Recommendations

| Setting	| Command	| Purpose |
| ------- | ------- | ------- |
| Require PIN every time | `ykman fido access set-pin-touch always` | Prevents unattended key use |
| Add backup key | Register second YubiKey and store safely | Redundancy |
| Use Windows Hello fallback | Enable Hello for Business with WebAuthn | Device-based MFA |
| Disable OTP if unused | `ykman config usb --disable OTP` | Reduces attack surface |

### Summary

After setup:

* YubiKey requires PIN + Touch to authenticate
* Windows SSH client supports ed25519-sk FIDO2 keys
* Compatible with server-side TPI + DS framework
* Okta/SSO MFA can integrate seamlessly via WebAuthn
* Optional use via WSL2 or Git Bash
