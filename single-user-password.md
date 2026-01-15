1. Verify sulogin is installed (it usually is)

```text
rpm -q util-linux
```

`sulogin` is part of `util-linux`.

2. Enforce password on emergency mode

Check the unit:

```text
systemctl cat emergency.service
```
You should see:

```text
ExecStart=-/usr/lib/systemd/systemd-sulogin-shell emergency
```

If present → emergency mode already requires a password
If missing → fix it (see override below)

3. Enforce password on rescue mode

Check:

```text
systemctl cat rescue.service
```

Expected:

```text
ExecStart=-/usr/lib/systemd/systemd-sulogin-shell rescue
```

4. If either is missing → create a systemd override (STIG-approved)

Emergency mode override
```text
sudo systemctl edit emergency.service
```

Paste:

```text
[Service]
ExecStart=
ExecStart=-/usr/lib/systemd/systemd-sulogin-shell emergency
```

Rescue mode override
```text
sudo systemctl edit rescue.service
```

Paste:

```text
[Service]
ExecStart=
ExecStart=-/usr/lib/systemd/systemd-sulogin-shell rescue
```

Reload:

```text
sudo systemctl daemon-reexec
```

5. Ensure root password is set (MANDATORY)

STIG assumes root authentication exists.

Check:

```text
passwd -S root
```

If locked:

```text
sudo passwd root
```

If root is locked → sulogin is useless → STIG fail

6. GRUB hardening (VERY IMPORTANT)

Even with sulogin, STIG also requires protection at boot.

Set GRUB password
```text
sudo grub2-mkpasswd-pbkdf2
```

Copy the hash, then edit:

```text
sudo vi /etc/grub.d/40_custom
```

Add:

```text
set superusers="root"
password_pbkdf2 root <PASTE_HASH_HERE>
```

Rebuild:

```text
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

This prevents:

* init=/bin/bash
* single
* systemd.unit=emergency.target

without authentication.

7. Test (DO THIS)

Emergency mode test
```text
sudo systemctl emergency
```

Expected:

```shell
Give root password for maintenance
(or press Control-D to continue):
```

Rescue mode test

```text
sudo systemctl rescue
```
