# Notes on SUMA / Spacewalk CLI

Display a list of current channels
```text
spacewalk-remove-channel -l
```

Manual sync of a channel
```text
spacewalk-repo-sync -c <channel_name>
```

Manual adding a channel via the CLI
```text
mgr-sync add channel <channel_name>
```

Reset an Organization password
```text
satpasswd <username>
```

Monitor spacewalk processes
```text
taskotop -H
```

Monitor spacewalk syncs
```text
spacewalk-watch-channel-sync.sh
```

Restart hung sync
```text
systemctl restart taskomatic
```

Reindex the Postgresql Database
```text
spacewalk-service stop
systemctl restart postgresql
spacewalk-sql --select-mode - <<<"REINDEX DATABASE susemanager;"
spacewalk-service start
```
