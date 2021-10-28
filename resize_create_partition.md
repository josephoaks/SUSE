# Resize partition and create new using Parted

## Resizing the partition

```text
pi1:~ # parted
```

*your output should look similar*

```text
GNU Parted 3.2
Using /dev/mmcblk1
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted)
```

Print the partition table
  
```text
(parted) print
```
  
*your output should look similar*

```text
(parted) print
Model: SD 00000 (sd/mmc)
Disk /dev/mmcblk1: 256GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system     Flags
 1      1049kB  68.2MB  67.1MB  primary  fat16           lba, type=0c
 2      68.2MB  1117MB  1049MB  primary  linux-swap(v1)  type=82
 3      1117MB  256GB   98.9GB  primary  btrfs           type=83
```

  **To resize select the partition you want to resize**
  
  ```text
  (parted) resize 3
  Warning: Partition /dev/mmcblk1p3 is being used. Are you sure you want to
  continue?
  Yes/No? yes
  End?  [256GB]? 100GB
  Warning: Shrinking a partition can cause data loss, are you sure you want to
  continue?
  Yes/No? yes
  ```

  **Next we need to create a new partition**

  ```text
  (parted) mkpart primary btrfs 100GB 256GB
  ```
  
  **toggle any flags you need or don't need**
  
  ```text
  (parted) toggle <#> FLAG on/off
  ```

  **And we are done lets exit parted**

  ```text
  (parted) quit
  ```

## Now we need to format our new partition
  
  ```shell
  mkfs.btrfs /dev/<deviceID[PartitionID]>
  ```

  *make note of the UUID you need that for the fstab entry*
  
  ```text
  pi1:~ # mkfs.btrfs /dev/mmcblk1p4
  btrfs-progs v4.19.1
  See http://btrfs.wiki.kernel.org for more information.

  Detected a SSD, turning off metadata duplication.  Mkfs with -m dup if you want to force metadata duplication.
  Label:              (null)
  UUID:               5916e33f-bb2a-4c6f-bb6d-cfd9a7cce806
  Node size:          16384
  Sector size:        4096
  Filesystem size:    145.37GiB
  Block group profiles:
    Data:             single            8.00MiB
    Metadata:         single            8.00MiB
    System:           single            4.00MiB
  SSD detected:       yes
  Incompat features:  extref, skinny-metadata
  Number of devices:  1
  Devices:
     ID        SIZE  PATH
      1   145.37GiB  /dev/mmcblk1p4
  ```

  **Next we are going to make a mount point for our new partition**
  
  ```shell
  mkdir <mountpoint>
  ```

  **Add the new partition to the fstab, that way on reboot it mounts the new parition**
  
  ```shell
  mount /dev/<deviceID[PartitionID]> /mountpoint
  ```
