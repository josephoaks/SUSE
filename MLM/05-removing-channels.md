# Removing Channels

[Home](README.md) › Removing Channels

Channels, with their metadata, can only be removed from the command line. `spacewalk-remove-channel` deletes a package's files and database entries **only when no other channel still references it**. That's why clones matter for reclaiming space.

```bash
mgrctl exec -ti -- spacewalk-remove-channel -l                       # list all channels as a tree (parent, indented children)
mgrctl exec -ti -- spacewalk-remove-channel -c <child-label>         # remove one channel
mgrctl exec -ti -- spacewalk-remove-channel -c <label1> -c <label2>  # remove several
mgrctl exec -ti -- spacewalk-remove-channel -a <parent-label>        # remove a parent and all its children

mgrctl exec -ti -- 'spacecmd -- softwarechannel_listsystems <label>' # who's subscribed (empty output = nobody)
```

## Reading `-l` output: vendor channels vs. CLM clones

Content Lifecycle Management (CLM) builds copy a source tree into one tree per environment, named `<project>-<environment>-<source-label>`. Example from a real server:

```
el9-pool-x86_64                                   <- vendor base (RHEL 9 / SUSE Liberty Linux 9 product)
    managertools-el9-pool-x86_64
    managertools-el9-updates-x86_64
    sll-9-updates-x86_64
    sll-as-9-updates-x86_64
    sll-cb-9-updates-x86_64
rhel-9-xdate-dev-el9-pool-x86_64                  <- CLM project "rhel-9-xdate", environment "dev"
    rhel-9-xdate-dev-managertools-el9-pool-x86_64
    rhel-9-xdate-dev-managertools-el9-updates-x86_64
rhel-9-xdate-qa-el9-pool-x86_64                   <- same project, environment "qa"
    rhel-9-xdate-qa-managertools-el9-pool-x86_64
    rhel-9-xdate-qa-managertools-el9-updates-x86_64
```

The clone chain here is `el9-pool` → `dev` → `qa`. Removing only the vendor tree frees almost nothing while the clones still reference its packages, and the tool won't allow it anyway.

## The clone guard

If clones exist, `spacewalk-remove-channel` refuses and removes nothing:

```
Error: cannot remove channel el9-pool-x86_64: clone channel(s) exist:
            rhel-9-xdate-dev-el9-pool-x86_64
```

Nothing is half-removed when this happens. Remove the clones first, **newest environment first**, then the source.

## Procedure: removing a vendor tree that has CLM clones

1. **Map the trees** with `spacewalk-remove-channel -l`. Identify the vendor base and every `<project>-<env>-` clone of it. Leave unrelated trees alone.

2. **Check subscriptions** on every base you'll remove:

   ```bash
   mgrctl exec -ti -- 'spacecmd -- softwarechannel_listsystems el9-pool-x86_64'
   mgrctl exec -ti -- 'spacecmd -- softwarechannel_listsystems rhel-9-xdate-dev-el9-pool-x86_64'
   mgrctl exec -ti -- 'spacecmd -- softwarechannel_listsystems rhel-9-xdate-qa-el9-pool-x86_64'
   ```

   Only the `INFO: Connected to ...` line and nothing else means no systems are subscribed. If any come back, move or unsubscribe them first.

3. **Remove the clones, last environment first:**

   ```bash
   mgrctl exec -ti -- spacewalk-remove-channel -a rhel-9-xdate-qa-el9-pool-x86_64
   mgrctl exec -ti -- spacewalk-remove-channel -a rhel-9-xdate-dev-el9-pool-x86_64
   ```

   A clean removal prints nothing. If one fails with "clone channel(s) exist", a later environment is still there.

4. **Remove the vendor tree:**

   ```bash
   mgrctl exec -ti -- spacewalk-remove-channel -a el9-pool-x86_64
   ```

   This one shows progress (`Deleting package metadata (62761)` and a progress bar) because it's where the packages actually live. A tree this size takes a while; let it finish before running anything else.

5. **Clean up what's left:**
   - **Delete the CLM project** in the Web UI: **Content Lifecycle → Projects → `<project>` → Delete**. Removing its channels doesn't remove the project, and its next build would fail pointing at channels that no longer exist.
   - Delete or edit **activation keys** that used these channels.
   - Delete the matching **bootstrap repository** if you created one.
   - Remove the channels from any **ISS (Inter-Server Sync)** or scheduled sync configuration.
   - Untick the product in **Admin → Setup Wizard → Products** if you don't want it re-added.

6. **Confirm the space came back:**

   ```bash
   mgrctl exec -ti -- spacewalk-remove-channel -l | grep -i el9    # should return nothing
   df -h /var/lib/containers/storage/volumes
   ```

   On a thin-provisioned VM disk, the hypervisor only gets the space back after a trim, which needs discard enabled on the virtual disk: `fstrim -av` on the host.

**Related:** [Products and channel sync](04-products-and-channels.md) · [spacecmd](06-spacecmd.md) · [Volumes and disk space](08-logs-and-volumes.md)

---

[← Products and Channel Sync](04-products-and-channels.md) · [Home](README.md) · [spacecmd: Day-to-Day Management →](06-spacecmd.md)
