# SUSE Multi-Linux Manager 5.x: Command Reference (Containerized)

For admins coming from SUSE Manager 4.x (RPM install) to MLM 5.x (Podman containers).

Commands are checked against the SUSE MLM 5.1/5.2 documentation and tested on an **MLM 5.1.3.1** server. Commands that only exist in 5.2 are labeled **(5.2+)**.

## The one thing to know

`mgradm` manages the containers **from the host**. `mgrctl` gets you **into** the server container. Every tool you used on SUMA 4 (`mgr-sync`, `spacecmd`, `spacewalk-*`, `salt`) still exists; it just runs inside the container:

```bash
mgrctl term                          # shell inside the server container
mgrctl exec -ti -- <command>         # run one command inside from the host
```

New to the container model? Start with [Concepts](01-concepts.md), then keep the [SUMA 4 → MLM 5 translation](12-suma4-translation.md) handy.

## Pages

| Page | What's in it |
|---|---|
| [Concepts: How MLM 5 Differs From SUMA 4](01-concepts.md) | Containers vs. RPM install, what runs where, the server containers |
| [Working Inside the Container (mgrctl)](02-mgrctl.md) | `mgrctl term/exec/cp`, Podman equivalents, handy aliases |
| [Server Administration (mgradm)](03-server-admin.md) | Start/stop/status, services, install, migrate from 4.3, backup/restore, support, GPG keys |
| [Products and Channel Sync](04-products-and-channels.md) | SCC credentials, `mgr-sync`, `spacewalk-repo-sync`, third-party products, sync debugging |
| [Removing Channels](05-removing-channels.md) | `spacewalk-remove-channel`, CLM clones, the clone guard, reclaiming space |
| [spacecmd: Day-to-Day Management](06-spacecmd.md) | Systems, channels, activation keys, groups, patching, scheduled actions |
| [Salt, API, Reports and Database](07-salt-api-database.md) | Salt CLI, `mgrctl api`, `spacewalk-report`, `spacewalk-sql` |
| [Logs and Persistent Volumes](08-logs-and-volumes.md) | Where every log lives, volume-to-path map, what survives a restart |
| [Proxy (mgrpxy)](09-proxy.md) | Proxy lifecycle and generating proxy configs on the server |
| [Certificates: Self-Signed to CA-Signed](10-certificates.md) | Podman secrets, preparing certs, 5.2 staged rotation, 5.1 secret replacement |
| [Updating and Upgrading MLM](11-updates-and-upgrades.md) | Maintenance updates, the 5.1 → 5.2 upgrade, proxy updates, PTF-loss warning |
| [SUMA 4 → MLM 5 Command Translation](12-suma4-translation.md) | Old command on the left, container equivalent on the right |

## I want to…

| Task | Go to |
|---|---|
| Start, stop or check the server | [Server Administration](03-server-admin.md) |
| Back up or restore | [Server Administration → Backup and restore](03-server-admin.md#backup-and-restore) |
| Add a product or sync a channel | [Products and Channel Sync](04-products-and-channels.md) |
| Trust a third-party repo key (NVIDIA, etc.) | [Server Administration → GPG keys](03-server-admin.md#third-party-gpg-keys-for-repo-sync) |
| Delete a channel tree and free disk space | [Removing Channels](05-removing-channels.md) |
| Patch systems or manage activation keys from the CLI | [spacecmd](06-spacecmd.md) |
| Find a log file | [Logs and Persistent Volumes](08-logs-and-volumes.md) |
| Replace the self-signed certificate | [Certificates](10-certificates.md) |
| Apply updates or move from 5.1 to 5.2 | [Updating and Upgrading](11-updates-and-upgrades.md) |
| Set up or update a proxy | [Proxy](09-proxy.md) |

## Sources

SUSE MLM 5.1/5.2 documentation: Backup and Restore; Database Backup Management; Starting and Stopping Containers; Containers Used by MLM; Persistent Container Volumes; Server Maintenance Update; Server Upgrade 5.1 → 5.2; Proxy Upgrade 5.1 → 5.2; Using mgr-sync; Synchronization CLI Tools; Third-party Channels; Support; spacecmd Reference; Import SSL Certificates; Migrate SSL Certificate Authorities; Proxy Deployment; Troubleshooting Taskomatic; Generate Reports. SUSE maintenance announcements for 5.1.1–5.1.3. uyuni-tools source and changelog. Command output from an MLM 5.1.3.1 server.
