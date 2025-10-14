#SELinux Policy

## Documented in the `tpi_exec.te`, `tpi_exec.fc`, `tpi_exec.if`

* Build commands:
```bash
checkmodule -M -m -o tpi_exec.mod tpi_exec.te
semodule_package -o tpi_exec.pp -m tpi_exec.mod -f tpi_exec.fc
semodule -i tpi_exec.pp
```

* Enforcement logic
* Audit verification

## Operational Flow Summary

| Step | Layer | Description |
| ---- | ----- | ----------- |
| 1	| DS LDAP	| Authenticates users, group membership |
| 2	| MFA/SSO	| YubiKey, Okta, or Keycloak verification |
| 3	| sudo | Restricts execution to tpi_exec |
| 4	| TPI Wrapper	| Dual-approval logic, logs to /var/log/tpi_exec.log |
| 5	| SELinux	| Allows execution only in tpi_exec_t context |
| 6	| Audit	| Logs all actions and denials |
