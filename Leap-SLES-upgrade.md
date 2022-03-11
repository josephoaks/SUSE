# Upgrade OpenSUSE Leap to SLES

1. `sudo zypper in SUSEConnect`
1. `sudo SUSEConnect -r <CODE> -p SLES/15.3/x86_64`
1. `SUSEConnect -p sle-module-basesystem/15.3/x86_64`
1. `zypper lr --url`
  this will list all the repositories, you will need to remove any that are associated with openSUSE
1. `zypper rr #` from the previous command list output for each that match opensuse, repeat till all are removed
1. `zypper dup --force-resolution`

reboot the system, you should be on SLES, check the /etc/os-release
