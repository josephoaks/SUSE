# SUSE Linux Enterprise Micro 5.2 setup for Raspberry Pi

This instruction set is designed for use with Raspberry Pi using the .raw.xz image file.

## Pre-setup work

1. Download the image file
1. Install image file on a MicroSD or USB thumb drive using your favorite method (for me that is using the Rasberry Pi Imager)
1. Now that it is installed on the MicroSD or USB thumb drive mount it in your favorite Linux OS, SUSE of course, we need some command line foo
*for this to work we need to configure a script to do things like set root password and other users, enable SSHD and what not*
1. Your drive has a lot of space left over, we are going to resize the /dev/sd(x)2 and make a third partition so first off expanding the second
partition

`fdisk -l` *this will give us information similar to this*

```text
Device     Boot Start     End Sectors  Size Id Type
/dev/sdb1        2048   34815   32768   16M  c W95 FAT32 (LBA)
/dev/sdb2       34816 5085150 5050335  2.4G 83 Linux
```

Next we are going to expand /dev/sdb2 using `parted`

`parted /dev/sdb`
```text
GNU Parted 3.2
Using /dev/sdb
Welcome to GNU Parted! Type 'help' to view a list of commands.

(parted)
```

Now we can print the free space using `print free` and resize partition 2 using `resizepart NUMBER END`
```text
(parted) print free
Model: Mass Storage Device (scsi)
Disk /dev/sdb: 32.0GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
        32.3kB  1049kB  1016kB           Free Space
 1      1049kB  17.8MB  16.8MB  primary  fat16        lba, type=0c
 2      17.8MB  2604MB  2586MB  primary  btrfs        type=83
        2604MB  32.0GB  29.4GB           Free Space

(parted) resizepart 2 200GB 
End?  [200GB]? 200GB

(parted) quit
```

Depending on the file system of partition 2 `btrfs` `Linux` etc... we can resize similar to this
```text
mount /dev/sdb2 /mnt
btrfs filesystem resize max /mnt
umount /mnt
```

Now we are ready to make our third parition for `combustion` *this will be the part that allows us to set things like the password*

Using `fdisk` make a new primary partition
```text
# fdisk /dev/sdb

Welcome to fdisk (util-linux 2.33.2).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Command (m for help): n
Partition type
   p   primary (2 primary, 0 extended, 2 free)
   e   extended (container for logical partitions)
Select (default p): p
Partition number (3,4, default 3):
First sector (60546876-62521343, default 60547072):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (60547072-62521343, default 62521343):

Created a new partition 3 of type 'Linux' and of size 964 MiB.

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
```

Again you can verify your partitions with `fdisk -l`

Now to configure the partition with `ext4` filesystem (or your filesystem of choice) and lable it.

```txt
mkfs.ext4 /dev/sdb3
e2label /dev/sdb3 ignition
```

Next we are going to mount the new partition and setup our script for the initial boot

```text
mount /dev/sdb3 /mnt
mkdir -p /mnt/combustion
```

Next we are going to setup a `script` file in the `/mnt/combustion` directory, to get a password for root, we need to create a hash using

```text
openssl passwd -6
Password:
Verifying - Password:
blahblahblah_some_really_long_hash_goes_here_blahblahblah
```

```text
#!/bin/bash
# combustion: network

# Redirect output to the console
exec > >(exec tee -a /dev/tty0) 2>&1

# Set a password for root, generate the hash with "openssl passwd -6"
echo 'root:blahblahblah_some_really_long_hash_goes_here_blahblahblah' | chpasswd -e

# Set hostname
echo "some_host_name" > /etc/hostname

# enable sshd and cockpit
systemctl enable sshd.service
systemctl enable --now cockpit.socket

# Uncomment the line below to register SLE Micro with activation key and email address
# SUSEConnect -r <REGISTRATION CODE> -e <EMAIL ADDRESS>

# Leave a marker
echo "Configured with combustion" > /etc/issue.d/combustion
```

Unmount the partition
`unmount /mnt`

Now you are ready to boot your Raspberry Pi
*If you configure your SUSEConnect to register on initial boot, it will more than likely fail due to Pi's not having an RTC*

### a lot of this can be seen from the [SUSE-AT-HOME](https://github.com/SUSE/suse-at-home/blob/main/install/Install-Slemicro-K3S-onRPi.md) github page where they show even more with K3S

# Register System / List extensions
```text
SUSEConnect -r <registration>
transactional-update register -p PackageHub/15.3/aarch64
```

# Deploying a simple webserver
SSH into the SLE Micro, and setup a www directory
```text
mkdir -p /srv/www/htdocs
```
You can put any html in here like a simple index.html file
```text
<html>
<h1>Hello World</h1>
</html>
```

Deploy a webserver container using podman
```text
podman run -d --name nginx:latest -p 80:80 -v /srv/www/htdocs:/usr/share/nginx/html/
```

Test the container
```text
podman ps
```
Open a browser and browse to the http of the server
