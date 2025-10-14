# This repository provides a complete security control plane built on:

## Component	Purpose

|389 Directory Server (DS) | Central identity and LDAP store |
|--------------------------|---------------------------------|
| YubiKey / FIDO2 / SSO	Multi-Factor | Authentication for privileged users |
| TPI Enforcement | Dual authorization for critical commands |
| SELinux + sudo | Kernel and user-space enforcement |
| Audit logging | Non-repudiable logs of every privileged action |

This stack ensures that no single operator can perform critical infrastructure changes without:

1. being authenticated via MFA/SSO, and

2. having a second authorized approver confirm the action.

## System Architecture

<pre>
┌────────────────────────────────────────────────────────────────┐
│                          Users / Admins                        │
│  MFA via YubiKey, Okta, or SSO (OIDC/SAML)                     │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│                   389 Directory Server (DS)                    │
│  - BaseDN: dc=example,dc=com                                   │
│  - Group: cn=Security-Officers,ou=Groups,dc=example,dc=com     │
│  - LDAP users: admin01, admin02, ...                           │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│                Host Enforcement Layer (target host)            │
│  - /usr/local/sbin/tpi_exec wrapper                            │
│  - /etc/sudoers.d/tpi_exec whitelist                           │
│  - SELinux module tpi_exec.pp                                  │
│  - /var/log/tpi_exec.log auditing                              │
└────────────────────────────────────────────────────────────────┘
</pre>

## Repository Layout

<pre>
tpi-enforcement/
├── README.md                    ← main documentation
├── mfa/
│   ├── yubikey/
│   │   ├── pam_u2f_setup.md
│   │   ├── example_u2f_keys
│   │   └── ssh_fido2_integration.md
│   └── sso/
│       ├── okta_oidc_setup.md
│       ├── keycloak_saml_setup.md
│       └── ipa_integration.md
├── tpi/
│   ├── tpi_exec
│   ├── tpi_exec.te
│   ├── tpi_exec.fc
│   ├── tpi_exec.if
│   ├── sudoers.d_tpi_exec
│   └── Makefile
└── docs/
    ├── DS_Setup.md
    ├── MFA_Integration.md
    ├── SELinux_Policy.md
    └── TPI_Framework.md
</pre>
