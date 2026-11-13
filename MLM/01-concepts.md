# Concepts: How MLM 5 Differs From SUMA 4

[Home](README.md) › Concepts: How MLM 5 Differs From SUMA 4

| | SUMA 4.x (RPM) | MLM 5.x (container) |
|---|---|---|
| Where the app lives | Directly on the host | Podman containers: `uyuni-server` (app) and a separate PostgreSQL container, plus helpers |
| Host-side admin tool | n/a | **`mgradm`**: install, upgrade, start/stop, backup, certs, support |
| Getting "inside" | You're already there | **`mgrctl`**: shell, exec, copy files, API calls, proxy config |
| Classic tools (`mgr-sync`, `spacecmd`, `spacewalk-*`, `salt`) | Run on host | Run **inside the server container** |
| Service control | `spacewalk-service` | `mgradm start/stop/restart` (spacewalk-service still works inside) |
| Persistent data | Host filesystem | Podman volumes under `/var/lib/containers/storage/volumes/` |
| Certificates | `/root/ssl-build`, `/etc/pki` | **Podman secrets** (`uyuni-ca`, `uyuni-cert`, `uyuni-key`, `uyuni-db-*`) |

**Rule of thumb:** `mgradm` manages the containers **from the host**. `mgrctl` gets you **into** the server container. Everything you used to run in SUMA 4 now runs through `mgrctl`.

## Server containers

| Container | Role |
|---|---|
| `uyuni-server` | Main product container |
| `uyuni-db` | PostgreSQL database (image `server-postgresql`) |
| `uyuni-hub-xmlrpc` | Hub XML-RPC gateway |
| `uyuni-saline` | Salt observability |
| `uyuni-server-attestation` | Confidential computing attestation |
| `uyuni-server-migration` | Migration helper |
| `uyuni-tftpd` | Optional TFTP (5.2+, off by default, `--tftpd-enable`) |

**Related:** [Working inside the container](02-mgrctl.md) · [Logs and volumes](08-logs-and-volumes.md) · [Certificates](10-certificates.md) · [SUMA 4 → MLM 5 translation](12-suma4-translation.md)

---

[Home](README.md) · [Working Inside the Container (mgrctl) →](02-mgrctl.md)
