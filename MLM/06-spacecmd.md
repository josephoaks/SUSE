# spacecmd: Day-to-Day Management

[Home](README.md) › spacecmd: Day-to-Day Management

```bash
mgrctl exec -ti -- spacecmd                  # interactive shell
mgrctl exec -ti -- spacecmd -- help          # full command list
```

One-shot form: `mgrctl exec -ti -- spacecmd -q -- <command>` (`-q` quiet). The examples below show just the `spacecmd` part.

## Listing

```bash
spacecmd -q -- system_list
spacecmd -q -- softwarechannel_list -t                # -t = tree view with children
spacecmd -q -- softwarechannel_listbasechannels
spacecmd -q -- softwarechannel_listchildchannels <base-label>
spacecmd -q -- softwarechannel_listrepos <label>
spacecmd -q -- softwarechannel_listsyncschedule
spacecmd -q -- activationkey_list
spacecmd -q -- group_list
spacecmd -q -- group_listsystems <group>
spacecmd -q -- configchannel_list
spacecmd -q -- user_list
spacecmd -q -- list_proxies
spacecmd -q -- get_certificateexpiration
spacecmd -q -- schedule_listpending
spacecmd -q -- schedule_listfailed
spacecmd -q -- schedule_listcompleted
```

## System info

```bash
spacecmd -q -- system_details <system>
spacecmd -q -- system_listupgrades <system>
spacecmd -q -- system_listerrata <system>
spacecmd -q -- system_listbasechannel <system>
spacecmd -q -- system_listchildchannels <system>
spacecmd -q -- system_listinstalledpackages <system>
spacecmd -q -- system_listhardware <system>
```

`<system>` can also be `group:NAME`, `channel:LABEL`, `search:QUERY`, or `ssm`.

## Add / remove

```bash
# Systems
spacecmd -q -- system_delete <system>
spacecmd -q -- group_addsystems <group> <system>
spacecmd -q -- group_removesystems <group> <system>

# Channels on a system
spacecmd -q -- system_setbasechannel <system> <base-label>
spacecmd -q -- system_addchildchannels <system> <child-label>
spacecmd -q -- system_removechildchannels <system> <child-label>

# Activation keys
spacecmd -q -- activationkey_addchildchannels <key> <child-label>
spacecmd -q -- activationkey_removechildchannels <key> <child-label>
spacecmd -q -- activationkey_delete <key>

# Repo sync schedule (Quartz cron, e.g. 0 0 1 * * ? = daily 1am)
spacecmd -q -- softwarechannel_setsyncschedule <label> <schedule>
spacecmd -q -- softwarechannel_removesyncschedule <label>
```

## Patching and actions

```bash
spacecmd -q -- system_applyerrata <system> <advisory>
spacecmd -q -- system_upgradepackage <system> '*'
spacecmd -q -- system_reboot <system>
spacecmd -q -- schedule_cancel <action-id>
spacecmd -q -- schedule_reschedule <action-id>
spacecmd -q -- schedule_getoutput <action-id>
```

**Related:** [Products and channel sync](04-products-and-channels.md) · [Salt and API](07-salt-api-database.md)

---

[← Removing Channels](05-removing-channels.md) · [Home](README.md) · [Salt, API, Reports and Database →](07-salt-api-database.md)
