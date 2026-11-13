# Working Inside the Container (`mgrctl`)

[Home](README.md) › Working Inside the Container (mgrctl)

## Getting inside the container (`mgrctl`)

`mgrctl` subcommands: `api`, `cp`, `exec`, `proxy`, `term`.

```bash
mgrctl term                          # interactive shell inside the server container
mgrctl exec -- <command>             # run one command inside (via sh -c)
mgrctl exec -ti -- <command>         # run one command inside, interactive (prompts, TTY)
mgrctl cp ./localfile server:/tmp/   # copy host -> container
mgrctl cp server:/tmp/file ./        # copy container -> host
mgrctl proxy --help                  # manage proxy configurations
mgrctl -v                            # tool version
```

Plain Podman equivalents:

```bash
podman ps                                  # running containers and image tags
podman exec -ti uyuni-server bash          # same as mgrctl term
podman logs -f uyuni-server                # container stdout/stderr
```

Both shells print a banner reminding you that changes outside persistent volumes are lost (see [Logs and Persistent Volumes](08-logs-and-volumes.md)).

**Tip:** Any command below can run from inside `mgrctl term`, or from the host prefixed with `mgrctl exec -ti --`.

## Handy aliases (add to `~/.bashrc` on the MLM host)

```bash
alias mgsh='mgrctl term'
alias mgx='mgrctl exec -ti --'
alias msync='mgrctl exec -ti -- mgr-sync'
alias mspace='mgrctl exec -ti -- spacecmd -q --'
alias mlogs='mgrctl exec -- tail -f /var/log/rhn/rhn_taskomatic_daemon.log'
```

With those: `msync list channels -c -f sp7`, `mspace system_list`, `mgx salt '*' test.ping`.

**Related:** [Concepts](01-concepts.md) · [What survives a restart](08-logs-and-volumes.md)

---

[← Concepts: How MLM 5 Differs From SUMA 4](01-concepts.md) · [Home](README.md) · [Server Administration (mgradm) →](03-server-admin.md)
