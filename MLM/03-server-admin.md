# Server Administration (`mgradm`)

[Home](README.md) › Server Administration (mgradm)

## Status, start, stop, restart

```bash
mgradm status
mgradm start
mgradm stop
mgradm restart
mgradm --version

systemctl status uyuni-server
journalctl -u uyuni-server -f
```

## Services inside the container

```bash
mgrctl exec -- spacewalk-service status          # still works; shows all Uyuni units
mgrctl exec -- service taskomatic restart
mgrctl exec -- systemctl status salt-master
```

## Install, migrate, rename

```bash
mgradm install podman <server-fqdn>        # fresh install (see --help for SSL/DB flags)
mgradm server rename                       # change server FQDN (5.1.1+)
```

**Migrating a SUMA 4.3 RPM server to containers:**

```bash
mgradm migrate podman <source-server-fqdn>
mgradm migrate podman --prepare <source-server-fqdn>   # copy data without stopping the source (do this first)
mgradm migrate podman --user <sudo-user> <source-fqdn> # non-root user needs passwordless sudo (NOPASSWD)
```

Prerequisites from the help text: SSH config for the source server is complete, an SSH agent is running with the key loaded, and Podman is installed locally. Migrating to a remote Podman host isn't supported. Other useful flags: `--mirror`, `--pullPolicy`, `--tag`, `--scc-user/--scc-password`, and the `--ssl-*` third-party cert flags.

## Updating and upgrading

See **[Updating and Upgrading MLM](11-updates-and-upgrades.md)** for the full procedures: maintenance updates within 5.1, and the 5.1 → 5.2 upgrade.

## Backup and restore

```bash
mgradm backup create /backup/dir                     # full backup (stops services during backup)
mgradm backup create --skipdatabase /backup/dir      # no DB, no downtime
mgradm backup create --skipvolumes <vol,vol> /backup/dir
mgradm backup create --extravolumes <vol> /backup/dir

# Restore: services do NOT auto-start afterwards
mgradm stop
mgradm backup restore /backup/dir
mgradm start
mgrctl exec -ti -- rhn-search cleanindex             # recommended after restore
```

Needs at least **3× the space** of the current install.

## Continuous database backup (5.2+)

```bash
mgradm backup db enable       # turn on WAL archiving
mgradm backup db status
mgradm backup db rebase       # fresh full snapshot, no restart
mgradm backup db restore      # destructive: replaces current DB
mgradm backup db disable      # add --purge-volume to delete stored backups
```

On 5.1, `mgradm migrate podman` and install expose a `--db-walbackup` flag. Check `mgradm backup --help` on your version.

## Support

```bash
mgradm support config          # supportconfig for the server (run on container host)
mgradm support ptf podman ...  # apply a PTF supplied by SUSE support (has --pullPolicy)
mgrpxy support config          # same for a proxy
```

## Third-party GPG keys for repo sync

```bash
mgradm gpg add <file-or-URL>   # e.g. mgradm gpg add https://.../repodata/repomd.xml.key
mgrctl exec -ti -- gpg --homedir /var/lib/spacewalk/gpgdir --list-keys
```

## Certificates

Full self-signed → CA-signed procedure: see **[Certificates: Self-Signed to CA-Signed](10-certificates.md)**.

**Related:** [Updating and upgrading](11-updates-and-upgrades.md) · [Certificates](10-certificates.md) · [Logs and volumes](08-logs-and-volumes.md)

---

[← Working Inside the Container (mgrctl)](02-mgrctl.md) · [Home](README.md) · [Products and Channel Sync →](04-products-and-channels.md)
