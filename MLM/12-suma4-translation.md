# SUMA 4 → MLM 5 Command Translation

[Home](README.md) › SUMA 4 → MLM 5 Command Translation

| SUMA 4.x | MLM 5.x |
|---|---|
| `mgr-sync refresh` | `mgrctl exec -ti -- mgr-sync refresh` |
| `spacewalk-repo-sync -c X` | `mgrctl exec -ti -- spacewalk-repo-sync --channel X` |
| `spacecmd system_list` | `mgrctl exec -ti -- spacecmd -q -- system_list` |
| `spacewalk-service restart` | `mgradm restart` |
| `spacewalk-service status` | `mgrctl exec -- spacewalk-service status` or `mgradm status` |
| `salt-key -L` | `mgrctl exec -ti -- salt-key -L` |
| `tail -f /var/log/rhn/...` | `mgrctl exec -- tail -f /var/log/rhn/...` |
| `spacewalk-sql -i` | `mgrctl exec -ti -- spacewalk-sql -i` |
| `spacewalk-remove-channel -a X` | `mgrctl exec -ti -- spacewalk-remove-channel -a X` (clones first) |
| `smdba backup-hot` | `mgradm backup create`, or `mgradm backup db enable` (5.2+) |
| `supportconfig` | `mgradm support config` |
| `zypper up` (server pkgs) | Host `zypper up`, then `mgradm upgrade podman` ([Updates](11-updates-and-upgrades.md)) |
| `scp file server:/tmp` | `scp` to host, then `mgrctl cp file server:/tmp/` |
| `rhn-ssl-tool` / `mgr-ssl-cert-setup` | `podman secret create --replace` + `mgradm restart`, or `mgradm ssl addca` / `rotate` (5.2+) |
| Import GPG key into `/var/lib/spacewalk/gpgdir` | `mgradm gpg add <file-or-URL>` |

**Related:** [Concepts](01-concepts.md) · [Working inside the container](02-mgrctl.md)

---

[← Updating and Upgrading MLM](11-updates-and-upgrades.md) · [Home](README.md)
