# Updating and Upgrading MLM

[Home](README.md) › Updating and Upgrading MLM

There are two different operations:

| | What it is | Example |
|---|---|---|
| **Maintenance update** | Newer build of the same version | 5.1.3.1 → newest 5.1.x |
| **Version upgrade** | Move to the next minor version | 5.1 → 5.2 |

Always do the maintenance update first. **5.1 must be on its latest maintenance update and running before upgrading to 5.2.** The database schema migrations depend on changes from those updates, and skipping them can cause migration errors and a server that won't start.

## Before either one

```bash
mgradm backup create /backup/mlm-$(date +%F)     # back up first
mgradm --version                                 # tool version
podman ps                                        # current image tags (e.g. server:5.1.3.1)
SUSEConnect --status-text                        # host OS + MLM extension
```

> **Downgrade and PTF-loss risk:** running `mgradm upgrade podman` when **no newer version is available** reverts the server to the base version and **removes all applied PTFs without asking**. Confirm an update is available before running it.

**How to tell whether an update is available:** after updating the host packages, the `--tag` default in `mgradm upgrade podman -h` shows the version `mgradm` will deploy. Compare it with the tag in `podman ps`. If they match, there's nothing to upgrade, so don't run it.

```bash
mgradm upgrade podman -h | grep -- '--tag'
podman ps --format '{{.Image}}'
```

**Hardened hosts:** if `/tmp` is mounted `noexec` (common with STIG profiles), `mgradm` can fail. Point it somewhere else first:

```bash
export TMPDIR=/path/to/other/tmp
```

---

## A. Maintenance update (stay on 5.1)

**SLES 15 SP7 host:**

```bash
zypper ref
zypper up                     # updates the host and the mgradm tooling
# check that a newer tag is available (see above), then:
mgradm upgrade podman         # pulls the new images and restarts the server
podman image prune -a         # clean up old images
```

**SL Micro 6.1 host:**

```bash
transactional-update
reboot                        # if updates were applied
mgradm upgrade podman
podman image prune -a
```

To pin a specific build instead of the newest, pass `--tag <image-tag>`. See all options with `mgradm upgrade podman -h`.

**Third-party certs:** if you use your own certificates, the upgrade can take `--ssl-db-ca-root`, `--ssl-db-cert` and `--ssl-db-key` for the database container.

Upgrades may leave `*.rpmnew` / `*.rpmsave` files. That's normal, and they aren't a to-do list. Required config changes are applied automatically; only look at them when troubleshooting something specific.

---

## B. Version upgrade: 5.1 → 5.2 (SLES 15 SP7 host)

**Before you start:**

1. Complete **A** so 5.1 is on its latest maintenance update, and confirm it's running.
2. Check the CA: 5.2 rejects CA certs whose Basic Constraints aren't marked `critical` with `CA:TRUE`. Older MLM-generated self-signed CAs may fail this.

   ```bash
   curl -s http://mlm.example.com/pub/RHN-ORG-TRUSTED-SSL-CERT | openssl x509 -noout -ext basicConstraints
   ```

   You want `critical` and `CA:TRUE`. If it's missing, plan a CA rotation with `mgradm ssl` (only available **after** the upgrade). You can upgrade safely as long as you rotate the CA and clients recognize it before starting the server.
3. If you use third-party certificates, have the CA, database certificate, and database key ready in PEM format.
4. Read the 5.2 release notes' known issues.

**Procedure:**

```bash
# 1. Confirm the starting point
SUSEConnect --status-text
#    Base OS: SUSE Linux Enterprise Server 15 SP7
#    Extension: SUSE Multi-Linux Manager Server 5.1 Extension

# 2. Patch the host; if anything was applied, stop and reboot
zypper patch
mgradm stop
reboot

# 3. Migrate the extension to 5.2
zypper migration
#    Select the SUSE Multi-Linux Manager Server 5.2 Extension

# 4. Stop and reboot
mgradm stop
reboot

# 5. Post-reboot checks
SUSEConnect --status-text     # should show the Server 5.2 Extension
mgradm --version              # should be 5.2.0 or higher

# 6. Upgrade the containers
mgradm start
mgradm upgrade podman         # follow the prompts; add --tftpd-enable to force the TFTP container on the server

# 7. Verify
podman ps                     # server:5.2.x and server-postgresql:5.2.x
podman image prune -a
```

During the 5.2 upgrade, the TFTP container is only deployed on the server if TFTP was already enabled. A proxy is the recommended place for TFTP autoinstallation.

**After the upgrade:**
- Validate the setup before resuming production use.
- The upgrade may create a `var-pgsql-backup` volume holding the old database. Remove it once you've confirmed everything works: `podman volume rm var-pgsql-backup`.
- Upgrade any 5.1 proxies next. A 5.2 server works with 5.1 proxies, but upgrading them is recommended.

## SL Micro 6.1 host instead

Same prerequisites. Steps differ only in the OS commands:

```bash
transactional-update patch
mgradm stop && reboot                     # if patches were applied
transactional-update migration --auto-agree-with-licenses --gpg-auto-import-keys
#   select SUSE Linux Micro 6.2 + SUSE Multi-Linux Manager Server 5.2 Extension
mgradm stop && reboot
SUSEConnect --status-text && mgradm --version
mgradm start
mgradm upgrade podman
podman ps
podman image prune -a
```

---

## C. Proxy updates

**Maintenance update (stay on 5.1):**

```bash
zypper up                     # upgrades mgrpxy (SL Micro: transactional-update)
# disconnected environment: also upgrade the proxy image packages
reboot
mgrpxy upgrade podman         # uses the default image tags
```

**5.1 → 5.2 (SLES 15 SP7 proxy host):**

```bash
cat /etc/os-release && mgrpxy --version
podman ps                                             # confirm the 5 proxy containers
zypper migration                                      # select the Proxy 5.2 Extension
zypper install suse-multi-linux-manager-5.2-<arch>-proxy*   # only if images come from RPMs, not the registry
reboot
mgrpxy upgrade podman
mgrpxy stop
mgrpxy start
```

**Related:** [Backup and restore](03-server-admin.md#backup-and-restore) · [Certificates and CA rotation](10-certificates.md) · [Proxy](09-proxy.md) · [Volumes (var-pgsql-backup)](08-logs-and-volumes.md)

---

[← Certificates: Self-Signed to CA-Signed](10-certificates.md) · [Home](README.md) · [SUMA 4 → MLM 5 Command Translation →](12-suma4-translation.md)
