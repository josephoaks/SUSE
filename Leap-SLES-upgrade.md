# Upgrade OpenSUSE Leap to SLES

1. `sudo zypper in SUSEConnect`
2. `sudo SUSEConnect -r <CODE> -p SLES/15.3/x86_64`
3. `sudo zypper dup --force-resolution`

*if an error occurs with the repos run `sudo zypper lr -d` and rerun the last command*

reboot the system, you should be on SLES, check the /etc/os-release
