# Logs and Persistent Volumes

[Home](README.md) › Logs and Persistent Volumes

## Inside the server container

| Log | Path |
|---|---|
| mgr-sync | `/var/log/rhn/mgr-sync.log` |
| Web API | `/var/log/rhn/rhn_web_api.log` |
| Web UI | `/var/log/rhn/rhn_web_ui.log` |
| Taskomatic | `/var/log/rhn/rhn_taskomatic_daemon.log` |
| Repo sync (per channel) | `/var/log/rhn/reposync/<channel-label>.log` |
| Tomcat | `/var/log/tomcat/catalina.out`, `localhost.log`, `manager.log`, `localhost_access_log.txt` |
| Salt master | `/var/log/salt/master` |

```bash
mgrctl exec -- tail -f /var/log/rhn/rhn_taskomatic_daemon.log
mgrctl exec -- tail -f /var/log/rhn/reposync/<label>.log
mgrctl exec -- tail -f /var/log/tomcat/catalina.out
```

On the host, the same logs are under `/var/lib/containers/storage/volumes/var-log/_data/`.

## On the host: persistent volumes

All under `/var/lib/containers/storage/volumes/<name>/_data/`

| Volume | Container path |
|---|---|
| `var-spacewalk` | `/var/spacewalk` (packages) |
| `var-pgsql` | `/var/lib/pgsql/data` (database) |
| `var-pgsql-backup` | `/var/lib/pgsql-backup` (created by upgrades; removable after validating) |
| `var-log` | `/var/log` |
| `var-salt` / `etc-salt` | `/var/lib/salt` / `/etc/salt` |
| `var-cache` | `/var/cache` |
| `var-cobbler` / `etc-cobbler` | `/var/lib/cobbler` / `/etc/cobbler` |
| `srv-www` | `/srv/www/` |
| `srv-salt`, `srv-pillar`, `srv-susemanager` | `/srv/salt`, `/srv/pillar`, `/srv/susemanager` |
| `srv-spacewalk`, `srv-tftpboot`, `srv-formulametadata` | `/srv/spacewalk`, `/srv/tftpboot`, `/srv/formula_metadata` |
| `etc-apache2`, `etc-rhn`, `etc-tomcat` | `/etc/apache2`, `/etc/rhn`, `/etc/tomcat` |
| `etc-sysconfig`, `etc-sssd`, `etc-postfix` | `/etc/sysconfig`, `/etc/sssd`, `/etc/postfix` |
| `ca-cert` | `/etc/pki/trust/anchors` |
| `root` | `/root` (MLM-generated CA lives in `root/_data/ssl-build`) |
| `run-salt-master` | `/run/salt/master` |

```bash
podman volume ls
podman volume inspect var-spacewalk
```

> **Anything changed inside the container outside these volumes is lost** on restart or upgrade.

`mgr-storage-server` moves all volumes to a dedicated disk.

**Related:** [Backup and restore](03-server-admin.md#backup-and-restore) · [Removing channels to free space](05-removing-channels.md)

---

[← Salt, API, Reports and Database](07-salt-api-database.md) · [Home](README.md) · [Proxy (mgrpxy) →](09-proxy.md)
