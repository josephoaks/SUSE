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
