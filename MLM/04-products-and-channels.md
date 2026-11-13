# Products and Channel Sync

[Home](README.md) › Products and Channel Sync

## SCC credentials and product data

```bash
mgrctl exec -ti -- mgr-sync list credentials
mgrctl exec -ti -- mgr-sync add credentials           # prompts for SCC org user/pass
mgrctl exec -ti -- mgr-sync delete credentials
mgrctl exec -ti -- mgr-sync refresh
mgrctl exec -ti -- mgr-sync -d 3 refresh              # max debug
mgrctl exec -ti -- mgr-sync --store-credentials       # store creds in a hidden local file
```

## Product sync

### `mgr-sync list` options

`mgr-sync list [-e] [-f FILTER] [--no-optional] [-c] {channels|products|credentials}`

| Flag | Meaning |
|---|---|
| `-e`, `--expand` | Also show children when the parent isn't installed yet |
| `-f`, `--filter WORD` | Only labels containing WORD (case-insensitive) |
| `--no-optional` | Hide optional channels |
| `-c`, `--compact` | Compact output |

```bash
mgrctl exec -ti -- mgr-sync list products
mgrctl exec -ti -- mgr-sync list products -e -f nvidia
mgrctl exec -ti -- mgr-sync add products              # interactive: pick by number
mgrctl exec -ti -- mgr-sync --no-sync add products    # add without starting sync
```

### Third-party products (e.g. NVIDIA Compute Module)

```bash
mgradm gpg add <nvidia-repomd.xml.key-URL>            # trust the key first
mgrctl exec -ti -- mgr-sync --no-sync add products
mgrctl exec -ti -- spacewalk-repo-sync --channel sle-module-nvidia-compute-15-pool-x86_64-we-sp7
```

Real NVIDIA labels from a 5.1 server with SLES 15 SP7: `sle-module-nvidia-compute-15-pool-x86_64-we-sp7`, `sle-module-nvidia-compute-15-updates-x86_64-we-sp7`, `nvidia-compute-sle-15-x86_64-we-sp7`. Confirm yours with `mgr-sync list channels -f nvidia`.

If the CLI balks at the NVIDIA license, add the product once via **Web UI → Admin → Setup Wizard → Products**, then sync from the CLI.

## Channel sync

### mgr-sync

```bash
mgrctl exec -ti -- mgr-sync list channels
mgrctl exec -ti -- mgr-sync list channels -c -f sp7       # compact, filtered
mgrctl exec -ti -- mgr-sync list channels --no-optional
mgrctl exec -ti -- mgr-sync add channel <label>
mgrctl exec -ti -- mgr-sync --no-sync add channel <label>
mgrctl exec -ti -- mgr-sync sync channel <label>
```

### spacewalk-repo-sync

```bash
mgrctl exec -ti -- spacewalk-repo-sync --list                   # custom channels and their repos
mgrctl exec -ti -- spacewalk-repo-sync --channel <label>        # sync one channel
mgrctl exec -ti -- spacewalk-repo-sync --channel <label> --type yum
mgrctl exec -ti -- spacewalk-repo-sync --channel <label> --non-interactive
mgrctl exec -ti -- spacewalk-repo-sync --deep-verify            # ignore cached checksums
mgrctl exec -ti -- spacewalk-repo-sync --force-all-errata       # re-import all patches
mgrctl exec -ti -- spacewalk-repo-sync --deep-verify --no-packages
mgrctl exec -ti -- man spacewalk-repo-sync                      # full option list
```

### Debugging a sync

```bash
mgrctl term
ZYPP_MEDIA_CURL_DEBUG=2 spacewalk-repo-sync --channel <label>
export URLGRABBER_DEBUG=DEBUG
spacewalk-repo-sync --channel <label> --type yum -vvv
unset URLGRABBER_DEBUG
```

Per-channel log: `/var/log/rhn/reposync/<channel-label>.log`
Custom HTTP headers per channel: `/etc/rhn/spacewalk-repo-sync/extra_headers.conf`

**Related:** [Removing channels](05-removing-channels.md) · [Trusting third-party GPG keys](03-server-admin.md#third-party-gpg-keys-for-repo-sync) · [Sync schedules in spacecmd](06-spacecmd.md) · [Repo sync logs](08-logs-and-volumes.md)

---

[← Server Administration (mgradm)](03-server-admin.md) · [Home](README.md) · [Removing Channels →](05-removing-channels.md)
