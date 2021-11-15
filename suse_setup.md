# This is how I setup SUSE for Rancher

### Register your system and add package

```text
SUSEConnect -r <your registration code>
SUSEConnect --list-extensions
SUSEConnect -p PackageHub/15.3/x86_64 (aarch64)
```
### Update and Install packages

```text
zypper ref;zypper up -y;zypper in -y -t pattern yast2_basis
zypper in -y \
  sudo \
  which \
  curl \
  nmap \
  git-core \
  bash-completion \
  bind-utils \
  k9s \
  apparmor-parser
```
*Adjust the apps to your needs/wants*

### Set hostname and configure firewalld (or disable it)

```text
hostnamectl set-hostname <fqdn>
systemctl disable --now firewalld
```

### Add a local user 

```text
useradd -m -g users <username>
passwd <username>
```

### Setup SUDO to allow the user to get to root without the need of a password

*Create and edit the /etc/suders.d/<username> and insert the following*

```text
<username> ALL=(ALL) NOPASSWD:ALL
```

### Using YAST setup the following to your needs

1. set region
1. set ntp servers
1. set network
