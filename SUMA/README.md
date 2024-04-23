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

Manually add a channel like NVIDIA
```text
spacewalk-repo-sync -c nvidia-compute-sle-15-x86_64-we-sp4 #select option "a"
```

Disconnect from SCC and register to RGS
1. SUMA WebUI, under the Admin -> Setup Wizard -> Org Creds, remove your old SCC credentials, the new process these are not required.
From the command line execute the following as root
```
SUSEConnect -d; SUSEConnect --cleanup
SUSEConnect --url https://rgs87187.updates.ranchergovernment.com --write-config
```
2. Update SUSE Manager
```
zypper ref
zypper up -y
```
2. Verify SUSE Manager is updated to 4.3.10
```
zypper se -si notes
```

Postgresql log files
```
/var/lib/pgsql/data/log
```

If Import fails with sql duplicate id and the updated ISSv2 patch does not fix it, then run
```
spacewalk-sql --select-mode - <<< "SELECT setval('suse_prdrepo_id_seq', (SELECT MAX(id)::BIGINT FROM suseproductsccrepository));"
```
