# Install 389-Directory Server (SLES 16)

## Install 389-Directory Server
```bash
sudo zypper in 389-ds-base openldap2-clients

sudo dscreate interactive

# or unattended:
sudo dscreate from-file ds01.inf
```

Example  ds01.inf:

```yaml
[general]
config_version = 2
full_machine_name = ds01.example.com
instance_name = ds01

[slapd]
root_password = ChangeMeNow!
port = 389
secure_port = 636
self_sign_cert = True

[backend-userroot]
create_suffix = True
suffix = dc=example,dc=com
sample_entries = Yes
```

## Define Organizational Units and Groups

02_configure_schema.ldif

```ldif
dn: ou=Groups,dc=example,dc=com
objectClass: organizationalUnit
ou: Groups

dn: cn=Security-Officers,ou=Groups,dc=example,dc=com
objectClass: groupOfNames
cn: Security-Officers
member: uid=admin01,ou=People,dc=example,dc=com
member: uid=admin02,ou=People,dc=example,dc=com
```

Apply:
```bash
ldapadd -x -D "cn=Directory Manager" -W -f 02_configure_schema.ldif
```

## Add Users

03_seed_users.ldif

```ldif
dn: uid=admin01,ou=People,dc=example,dc=com
objectClass: inetOrgPerson
cn: admin01
sn: Administrator
uid: admin01
userPassword: {SSHA}abc123...

dn: uid=admin02,ou=People,dc=example,dc=com
objectClass: inetOrgPerson
cn: admin02
sn: Administrator
uid: admin02
userPassword: {SSHA}xyz456...
```

Apply:
```bash
ldapadd -x -D "cn=Directory Manager" -W -f 03_seed_users.ldif
```

## Enable TLS (LDAPS)

```bash
dsctl ds01 tls generate-server-cert
dsconf -D "cn=Directory Manager" ldap://localhost security set --tls-required=on
```
