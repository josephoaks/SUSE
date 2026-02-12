# Upgrade OpenSUSE Leap to SLES

1. `zypper in yast2-registration rollback-helper ` *install 2 packages to help with the upgrade*
1. `systemctl enable rollback` *not needed but good to have incase something goes wrong*
1. `yast2 registration` *register with the SCC your email/subscription code*
1. `yast2 migration` *preforms the actual migration, this will show you which products are available to migrate to*
1. `zypper rm $(zypper --no-refresh packages --orphaned | gawk '{print $5}' | tail -n +5)` *cleanup process of orphaned packages*
1. `reboot`

Once rebooted, you can check the /etc/os-release to verify the migration.


## Desktop is installed

If Desktop is installed, extra steps are required for branding

1. `SUSEConnect --status` *check for registered products*
1. `SUSEConnect -p PackageHub/<ver>/x86_64` *register products if needed, like PackageHub for libreoffice*
1. `zypper dup --allow-vendor-change` *this replaces Leap core + KDE packages with SLE equivalents*
1. remove openSUSE Branding
   ```bash
   zypper rm \
   distribution-logos-openSUSE-Leap \
   distribution-logos-openSUSE-icons \
   libreoffice-branding-openSUSE \
   hicolor-icon-theme-branding-openSUSE \
   lifecycle-data-openSUSE
   ```
1. remove hardcoded openSUSE theme
   ```bash
   sed -i 's|GRUB_THEME=.*||g' /etc/default/grub
   grub2-mkconfig -o /boot/grub2/grub.cfg
   ```
1. `zypper refresh` *refresh zypper*

## Final State Achieved

* SLES 15 SP6 base
* Desktop Applications module
* KDE Plasma desktop
* SLE branding (GRUB, Plymouth, GTK, Firefox, etc.)
* No openSUSE branding packages
* PackageHub enabled for desktop apps
* Enterprise-clean RPM database
