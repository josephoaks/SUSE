# Simple process to update your Raspberry Pi eeprom

Use this process to update the eeprom on your Pi(s) to the latest version *this is completely optional*
If you are not running Raspbian or Ubuntu, I recommend getting a spare micro-SD card and install Raspbian
or Ubuntu to carry out the following steps.

## Raspbian or Ubuntu OS

Insure you do a package update

```text
sudo apt update
```

Next update yoru package

```text
sudo apt full-upgrade
```

At this point, depending on how often you update your OS, you may need to reboot

```text
sudo reboot
```

## Update the eeprom

Check to see if there is a new version first...

```text
sudp rpi-eeprom-update
```

If an update is avialable 

```text
sudo rpi-eeprom-update -a
```

Once done reboot

```text
sudo reboot
```

