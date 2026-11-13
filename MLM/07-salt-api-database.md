# Salt, API, Reports and Database

[Home](README.md) › Salt, API, Reports and Database

## Salt (inside the container)

Standard Salt CLI, running inside `uyuni-server`. Default log file is `/var/log/salt/master`.

```bash
mgrctl exec -ti -- salt-key -L                         # list keys
mgrctl exec -ti -- salt-key -a <minion-id>             # accept
mgrctl exec -ti -- salt-key -d <minion-id>             # delete
mgrctl exec -ti -- salt '*' test.ping
mgrctl exec -ti -- salt '<minion>' cmd.run 'uptime'
mgrctl exec -ti -- salt '<minion>' state.apply
mgrctl exec -ti -- salt '*' state.apply certs          # deploy the CA (the "certs" state)
mgrctl exec -ti -- salt --preview-target 'web*'        # show which minions match, run nothing
mgrctl exec -ti -- salt -b 10 '*' state.apply          # batch: 10 minions at a time
```

The SUSE docs deploy the CA through the Web UI (System Set Manager → **Apply States**, then **Apply Highstate**). `state.apply certs` is the CLI equivalent for the CA part only.

## API from the host (`mgrctl api`)

```bash
mgrctl api login
mgrctl api get user/getDetails login=admin
mgrctl api post user/create login=test password=testXX firstName=F lastName=L email=test@localhost
mgrctl api post user/create '{"login":"test","password":"testXX","firstName":"F","lastName":"L","email":"test@localhost"}'
mgrctl api logout
```

Paths follow the API namespaces (`system.listSystems` → `system/listSystems`). Check parameter names in the API reference for each call.

## Reports and database

```bash
mgrctl exec -ti -- spacewalk-report                    # list reports
mgrctl exec -ti -- spacewalk-report inventory          # CSV report
mgrctl exec -ti -- spacewalk-report --info <report>

mgrctl exec -ti -- spacewalk-sql -i                    # interactive SQL shell (main DB)
mgrctl exec -- spacewalk-sql --select-mode - <<< "SELECT label FROM rhnChannel;"
mgrctl exec -- spacewalk-sql --reportdb --select-mode - <<< "SELECT now();"   # reporting DB connectivity test
```

Usage: `spacewalk-sql [-i | [OPTIONS] [file.sql | -]]`. `-i` stands alone; the options `--verbose`, `--reportdb`, `--select-mode`, `--select-mode-direct` go with a `.sql` file or `-` for stdin.

**Related:** [spacecmd](06-spacecmd.md) · [Certificates (deploying the CA)](10-certificates.md)

---

[← spacecmd: Day-to-Day Management](06-spacecmd.md) · [Home](README.md) · [Logs and Persistent Volumes →](08-logs-and-volumes.md)
