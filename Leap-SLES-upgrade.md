# Upgrade OpenSUSE Leap to SLES

1. `zypper in yast2-registration rollback-helper ` *install 2 packages to help with the upgrade*
1. `systemctl enable rollback` *not needed but good to have incase something goes wrong*
1. `yast2 registration` *register with the SCC your email/subscription code*
1. `yast2 migration` *preforms the actual migration, this will show you which products are available to migrate to*
1. `zypper rm $(zypper --no-refresh packages --orphaned | gawk '{print $5}' | tail -n +5)` *cleanup process of orphaned packages*
1. `reboot`

Once rebooted, you can check the /etc/os-release to verify the migration.
