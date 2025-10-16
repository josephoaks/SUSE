#!/bin/bash
# 389 Directory Server + MFA + Two-Person-Integrity + SELinux setup (SLES 15/16)

set -euo pipefail
LOGFILE="/var/log/tpi_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
Y="\033[1;33m"; G="\033[1;32m"; R="\033[1;31m"; Z="\033[0m"

echo -e "${Y}Starting setup: $(timestamp)${Z}"

read -p "Enter primary DS admin username: " ADMIN1
read -p "Enter secondary DS approver username: " ADMIN2
read -p "Enter Directory Manager password: " -s DIRMAN_PASS; echo
read -p "Enter DS instance name [ds01]: " DS_INSTANCE; DS_INSTANCE=${DS_INSTANCE:-ds01}
read -p "Approval timeout (seconds) [300]: " TIMEOUT; TIMEOUT=${TIMEOUT:-300}

# --- 389-DS install / detect -------------------------------------------------
echo -e "${G}Installing 389-DS and SELinux tools...${Z}"
zypper -n in 389-ds policycoreutils selinux-tools checkpolicy || true

if [ -x /usr/lib/dirsrv/dscreate ]; then
  DSCREATE="/usr/lib/dirsrv/dscreate"
elif [ -x /usr/sbin/dscreate ]; then
  DSCREATE="/usr/sbin/dscreate"
else
  echo "[ERROR] dscreate not found. Install 389-DS first."; exit 1
fi
echo "[INFO] Using dscreate at: $DSCREATE"

# --- DS instance -------------------------------------------------------------
cat >/tmp/ds.inf <<EOF
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

"$DSCREATE" from-file /tmp/ds.inf
systemctl enable --now dirsrv@${DS_INSTANCE}
echo "[OK] DS instance ${DS_INSTANCE} created."

# --- MFA placeholder ---------------------------------------------------------
if command -v ykman >/dev/null 2>&1; then
  echo "Detected YubiKey Manager."
  ykman info || echo "Insert key to register later with pamu2fcfg."
else
  echo "YubiKey tools not found. Placeholder for Okta/Auth0 PAM integration."
fi

# --- Create TPI approver group ----------------------------------------------
TPI_GROUP=tpi_approvers
echo -e "${G}Creating TPI group and users...${Z}"
for u in "$ADMIN1" "$ADMIN2"; do
  if ! id "$u" &>/dev/null; then
    echo "[INFO] Creating local user $u ..."
    useradd -m "$u"
  fi
done
groupadd -f "$TPI_GROUP"
usermod -aG "$TPI_GROUP" "$ADMIN1"
usermod -aG "$TPI_GROUP" "$ADMIN2"

# --- TPI wrapper -------------------------------------------------------------
echo -e "${G}Deploying tpi_exec...${Z}"
install -m 750 -o root -g root /dev/null /usr/bin/tpi_exec
cat >/usr/bin/tpi_exec <<EOF
#!/bin/bash
CMD="\$@"
LOCKFILE="/var/lock/tpi_action.lock"
TIMEOUT=${TIMEOUT}
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

if [ -f "\$LOCKFILE" ]; then
  FIRST_USER=\$(cut -d' ' -f1 "\$LOCKFILE")
  if [ "\$FIRST_USER" = "\$USER" ]; then
    echo "[TPI] Same user cannot self-approve."; exit 1
  fi
  echo "[TPI] \$(timestamp): Second authorization by \$USER. Executing \$CMD"
  rm -f "\$LOCKFILE"; exec \$CMD
else
  echo "[TPI] \$(timestamp): First approver (\$USER) recorded for '\$CMD'"
  echo "\$USER \$(timestamp)" >"\$LOCKFILE"; chmod 600 "\$LOCKFILE"
  ( sleep \$TIMEOUT; [ -f "\$LOCKFILE" ] && rm -f "\$LOCKFILE" ) & disown
  exit 0
fi
EOF
chmod 750 /usr/bin/tpi_exec
chown root:${TPI_GROUP} /usr/bin/tpi_exec

# --- sudoers integration -----------------------------------------------------
cat >/etc/sudoers.d/tpi_exec <<EOF
Cmnd_Alias TPI_CMDS = /usr/bin/tpi_exec *
%${TPI_GROUP} ALL=(root) NOPASSWD: TPI_CMDS
Defaults!/usr/bin/tpi_exec !authenticate
EOF
chmod 440 /etc/sudoers.d/tpi_exec

# --- SELinux policy ----------------------------------------------------------
echo -e "${G}Checking for external SELinux policy...${Z}"
SELINUX_POLICY_DIR="/usr/share/selinux/packages/tpi_exec"
SELINUX_TE="${SELINUX_POLICY_DIR}/tpi_exec.te"
SELINUX_FC="${SELINUX_POLICY_DIR}/tpi_exec.fc"

if command -v checkmodule >/dev/null 2>&1 && [ -f "$SELINUX_TE" ]; then
    echo "[INFO] Found policy files: $SELINUX_TE and (optional) $SELINUX_FC"
    TMPMOD="/tmp/tpi_exec.mod"
    TMPPKG="/tmp/tpi_exec.pp"

    checkmodule -M -m -o "$TMPMOD" "$SELINUX_TE"
    if [ -f "$SELINUX_FC" ]; then
        semodule_package -o "$TMPPKG" -m "$TMPMOD" -f "$SELINUX_FC"
    else
        semodule_package -o "$TMPPKG" -m "$TMPMOD"
    fi

    semodule -i "$TMPPKG"
    restorecon -v /usr/bin/tpi_exec
    echo "[OK] SELinux policy applied successfully."
else
    echo "[WARN] SELinux tools or policy files missing. Skipping SELinux policy install."
fi

# --- Verification ------------------------------------------------------------
echo -e "${Y}Verification:${Z}"
echo " sudo /usr/local/sbin/tpi_exec systemctl status dirsrv@${DS_INSTANCE}"
echo " Then rerun as second approver to execute."
echo -e "${G}Setup complete.${Z}"
