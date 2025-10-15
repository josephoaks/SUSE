#!/bin/bash
# Automated setup: 389 Directory Server + MFA + TPI + SELinux
# Works on SLES 16 with 389-ds-base

set -euo pipefail
LOGFILE="/var/log/tpi_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

### Colors
YELLOW="\033[1;33m"; GREEN="\033[1;32m"; RED="\033[1;31m"; RESET="\033[0m"

echo -e "${YELLOW}Starting setup: $(timestamp)${RESET}"

### Prompt for inputs
read -p "Enter primary DS admin username: " ADMIN1
read -p "Enter secondary DS approver username: " ADMIN2
read -p "Enter Directory Manager password: " -s DIRMAN_PASS
echo
read -p "Enter FQDN for DS instance [ds01.local]: " HOSTNAME
HOSTNAME=${HOSTNAME:-ds01.local}
read -p "Enter DS instance name [ds01]: " DS_INSTANCE
DS_INSTANCE=${DS_INSTANCE:-ds01}
read -p "Approval timeout (seconds) [300]: " TIMEOUT
TIMEOUT=${TIMEOUT:-300}

### Install base packages
echo -e "${GREEN}Installing 389-DS and SELinux tools...${RESET}"
zypper -n in 389-ds-base selinux-policy selinux-tools policycoreutils checkpolicy pam_u2f libfido2-1 auditd || true

### Configure 389 Directory Server
echo -e "${GREEN}Creating DS instance '${DS_INSTANCE}'...${RESET}"

cat > /tmp/ds.inf <<EOF
[general]
config_version = 2

[slapd]
instance_name = ${DS_INSTANCE}
server_port = 389
secure_port = 636
suffix = dc=example,dc=com
root_dn = cn=Directory Manager
root_password = ${DIRMAN_PASS}
self_sign_cert = True
EOF

dscreate from-file /tmp/ds.inf

systemctl enable --now dirsrv@${DS_INSTANCE}
dsctl ${DS_INSTANCE} status

### Configure MFA (YubiKey or Okta placeholder)
echo -e "${GREEN}Configuring MFA integration...${RESET}"

if command -v ykman >/dev/null 2>&1; then
  echo "Detected YubiKey Manager."
  ykman info || echo "Ensure your YubiKey is inserted."
  mkdir -p /etc/Yubico /home/${ADMIN1}/.config/Yubico
  echo "Run on client to register YubiKey: pamu2fcfg -u ${ADMIN1} >> ~/.config/Yubico/u2f_keys"
else
  echo "YubiKey tools not found. Skipping direct pairing."
  echo "SSO/MFA placeholder for Okta, Auth0, or other PAM provider."
fi

### Create TPI approver group
TPI_GROUP=tpi_approvers
echo -e "${GREEN}Creating TPI group and adding users...${RESET}"
groupadd -f $TPI_GROUP
usermod -aG $TPI_GROUP $ADMIN1
usermod -aG $TPI_GROUP $ADMIN2

### Create tpi_exec wrapper
echo -e "${GREEN}Deploying tpi_exec script...${RESET}"
install -d /usr/local/sbin
cat > /usr/local/sbin/tpi_exec <<EOF
#!/bin/bash
CMD="\$@"
LOCKFILE="/var/lock/tpi_action.lock"
TIMEOUT=${TIMEOUT}

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

if [ -f "\$LOCKFILE" ]; then
    FIRST_USER=\$(cut -d' ' -f1 "\$LOCKFILE")
    if [ "\$FIRST_USER" = "\$USER" ]; then
        echo "[TPI] Same user cannot self-approve. Denied."
        exit 1
    fi
    echo "[TPI] \$(timestamp): Second authorization by \$USER. Executing \$CMD"
    rm -f "\$LOCKFILE"
    exec \$CMD
else
    echo "[TPI] \$(timestamp): First approver (\$USER) recorded for '\$CMD'"
    echo "\$USER \$(timestamp)" > "\$LOCKFILE"
    chmod 600 "\$LOCKFILE"
    (
      sleep \$TIMEOUT
      rm -f "\$LOCKFILE" 2>/dev/null
    ) & disown
    exit 0
fi
EOF
chmod 750 /usr/local/sbin/tpi_exec
chown root:$TPI_GROUP /usr/local/sbin/tpi_exec

### Add sudoers policy
cat > /etc/sudoers.d/tpi_exec <<EOF
Cmnd_Alias TPI_CMDS = /usr/local/sbin/tpi_exec *
%${TPI_GROUP} ALL=(root) NOPASSWD: TPI_CMDS
Defaults!/usr/local/sbin/tpi_exec !authenticate
EOF
chmod 440 /etc/sudoers.d/tpi_exec

### Install SELinux policy
echo -e "${GREEN}Installing SELinux policy for tpi_exec...${RESET}"
cat > /tmp/tpi_exec.te <<'TE'
module tpi_exec 1.0;
require {
    type user_t, systemctl_exec_t, bin_t, var_log_t;
    class file { read open execute getattr append };
}
type tpi_exec_t;
type tpi_exec_exec_t;
application_domain(tpi_exec_t)
files_type(tpi_exec_exec_t)
domain_auto_trans(user_t, tpi_exec_exec_t, tpi_exec_t)
allow tpi_exec_t systemctl_exec_t:file { read open execute getattr };
allow tpi_exec_t bin_t:file { read open execute getattr };
allow tpi_exec_t var_log_t:file append;
TE
checkmodule -M -m -o /tmp/tpi_exec.mod /tmp/tpi_exec.te
semodule_package -o /tmp/tpi_exec.pp -m /tmp/tpi_exec.mod
semodule -i /tmp/tpi_exec.pp
semanage fcontext -a -t tpi_exec_exec_t "/usr/local/sbin/tpi_exec"
restorecon -v /usr/local/sbin/tpi_exec

### Verification
echo -e "${YELLOW}Verification Steps:${RESET}"
echo "1. sudo /usr/local/sbin/tpi_exec systemctl status dirsrv@${DS_INSTANCE}"
echo "2. Run again as second approver to execute."
echo "3. Test MFA login via SSH or console."

echo -e "${GREEN}Setup complete!${RESET}"
