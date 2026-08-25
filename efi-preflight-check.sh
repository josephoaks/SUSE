#!/bin/bash
#
# efi-preflight-check.sh
#
# UEFI bootloader audit/repair for SLES (Secure Boot is assumed OFF).
#
# Two modes of operation:
#
#   1. OFFLINE REPAIR (default)
#      Run from a live/rescue ISO with the target SLES root mounted at
#      --root PATH (default /mnt/sysroot). For btrfs systems this MUST be
#      the @ subvolume, not the top of the filesystem. Use --fix to
#      actually apply changes; without it you get a read-only audit.
#
#   2. LIVE AUDIT (--live)
#      Run from the currently-booted SLES system itself. Audit only,
#      never modifies anything regardless of --fix. Useful as a sanity
#      check before/after migration without having to rescue-boot.
#
# Typical post-Leap-to-SLES use (rescue ISO):
#   ./efi-preflight-check.sh --root /mnt/sysroot              # audit
#   ./efi-preflight-check.sh --fix --root /mnt/sysroot --id sles
#
# Typical live use:
#   ./efi-preflight-check.sh --live
#

set -euo pipefail

FIX_MODE=0
LIVE_MODE=0
ROOT_MNT="${ROOT_MNT:-/mnt/sysroot}"
FORCE_ID=""

usage() {
  cat <<EOF
Usage: $0 [--fix] [--live] [--root PATH] [--id sles|opensuse]

  --fix              Apply repairs (offline mode only; ignored in --live mode).
                     Without this flag the script audits and reports only.
  --live             Audit the currently-running system. No mounts, no chroot,
                     no fixes. Implies read-only. Useful pre/post migration.
  --root PATH        Where the installed system root is mounted (offline mode).
                     Default: /mnt/sysroot. For btrfs use subvol=@.
  --id NAME          Force bootloader-id (e.g. 'sles' or 'opensuse').
                     Default: detected from /etc/os-release.

Secure Boot:
  This build assumes Secure Boot is OFF on all target systems. The script
  uses grub2-install directly, refreshes the fallback BOOTX64.EFI from
  grubx64.efi, and skips all shim/MOK handling. If you ever need to support
  Secure Boot ON, use the original script.

What --fix does (offline mode only):
  1. Verifies live ISO is in UEFI mode.
  2. Confirms target root mount and mounts /boot, /boot/efi from its fstab.
  3. Detects ESP layout: which of /EFI/{sles,opensuse,SUSE} actually has files.
  4. Detects SLES bootloader-id from os-release.
  5. Bind-mounts /dev /proc /sys /sys/firmware/efi/efivars /run into chroot.
  6. Backs up NVRAM to /tmp before any change.
  7. Inside chroot: runs
       grub2-install --target=x86_64-efi --efi-directory=/boot/efi \\
                     --bootloader-id=ID --recheck
     followed by grub2-mkconfig -o /boot/grub2/grub.cfg.
  8. Refreshes fallback /EFI/BOOT/BOOTX64.EFI from /EFI/ID/grubx64.efi.
     This is what SUSE's update-bootloader misses after Leap->SLES, where
     the stale Leap-era fallback survives the migration and gets booted
     by firmware that prefers the fallback path over named NVRAM entries.
  9. Cleans stale NVRAM entries labelled sles/opensuse/SUSE/SLES-* and
     creates ONE fresh entry pointing at the correct loader. Promotes it
     to BootOrder[0]. Idempotent: re-running won't pile up duplicates.

What --live does:
  Steps 1, 3, 4, plus a read-only NVRAM dump and a sanity check on the
  fallback binary. Reports any drift. Never modifies anything.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX_MODE=1 ;;
    --live) LIVE_MODE=1 ;;
    --root) ROOT_MNT="$2"; shift ;;
    --id) FORCE_ID="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

# --live forces read-only and runs against /
if [ "$LIVE_MODE" -eq 1 ]; then
  if [ "$FIX_MODE" -eq 1 ]; then
    echo "WARN: --fix is ignored in --live mode (live runs are audit-only)" >&2
    FIX_MODE=0
  fi
  ROOT_MNT="/"
fi

log()  { printf '[%s] %s\n' "$1" "$2"; }
fail() { log FAIL "$1"; exit 1; }

# Helper: resolve a path under the target root, handling ROOT_MNT="/"
target_path() {
  if [ "$ROOT_MNT" = "/" ]; then
    echo "$1"
  else
    echo "$ROOT_MNT$1"
  fi
}

# ---------- 1. Environment sanity ----------
log INFO "==== ENVIRONMENT ===="
if [ "$LIVE_MODE" -eq 1 ]; then
  log INFO "Mode: LIVE AUDIT (running against /)"
else
  log INFO "Mode: OFFLINE (target root: $ROOT_MNT, fix=$FIX_MODE)"
fi

[ "$(id -u)" -eq 0 ] || fail "Must run as root"
[ -d /sys/firmware/efi ] || fail "System is not in UEFI mode"
log OK "UEFI mode confirmed"

# Tools we need in both modes
for cmd in efibootmgr lsblk findmnt blkid awk; do
  command -v "$cmd" >/dev/null || fail "Missing tool: $cmd"
done

# Offline mode needs more
if [ "$LIVE_MODE" -eq 0 ]; then
  for cmd in chroot mount od cmp; do
    command -v "$cmd" >/dev/null || fail "Missing tool (offline mode): $cmd"
  done
fi
log OK "Required tools present"

# ---------- 2. Verify target root (offline only) ----------
if [ "$LIVE_MODE" -eq 0 ]; then
  log INFO "==== TARGET ROOT: $ROOT_MNT ===="
  [ -d "$ROOT_MNT" ] || fail "$ROOT_MNT does not exist"
  findmnt -n "$ROOT_MNT" >/dev/null || fail "$ROOT_MNT is not a mountpoint"

  [ -x "$ROOT_MNT/usr/sbin/grub2-install" ] || \
    fail "No grub2-install in target — wrong root mounted?"
  log OK "Target root contains grub2 tooling"

  if [ -d "$ROOT_MNT/.snapshots" ] && [ ! -f "$ROOT_MNT/etc/os-release" ]; then
    fail "Target looks like btrfs top-level, not @ subvol. Mount with -o subvol=@"
  fi

  # ---------- 3. Mount /boot, /boot/efi from target's fstab ----------
  ensure_mount() {
    local mp="$1"
    if findmnt -n "$ROOT_MNT$mp" >/dev/null; then
      log OK "$mp already mounted"
      return
    fi
    local entry
    entry=$(awk -v mp="$mp" '$1 !~ /^#/ && $2 == mp {print $1; exit}' \
      "$ROOT_MNT/etc/fstab" 2>/dev/null || true)
    if [ -z "$entry" ]; then
      log WARN "No fstab entry for $mp — skipping"
      return
    fi
    local dev
    case "$entry" in
      UUID=*)     dev=$(blkid -U "${entry#UUID=}" || true) ;;
      LABEL=*)    dev=$(blkid -L "${entry#LABEL=}" || true) ;;
      PARTUUID=*) dev=$(blkid -t "$entry" -o device | head -1) ;;
      *)          dev="$entry" ;;
    esac
    [ -n "$dev" ] && [ -b "$dev" ] || \
      fail "Cannot resolve fstab entry '$entry' to a block device"
    if [ "$FIX_MODE" -eq 1 ]; then
      mount "$dev" "$ROOT_MNT$mp"
      log FIX "Mounted $dev at $ROOT_MNT$mp"
    else
      log WARN "$mp not mounted (would mount $dev in --fix mode)"
    fi
  }
  ensure_mount /boot
  ensure_mount /boot/efi

  [ -d "$ROOT_MNT/boot/efi/EFI" ] || \
    fail "$ROOT_MNT/boot/efi/EFI not present — ESP not mounted"
fi

# ---------- 4. Identify EFI partition ----------
EFI_MOUNT=$(target_path /boot/efi)
if ! findmnt -n "$EFI_MOUNT" >/dev/null; then
  fail "$EFI_MOUNT is not a mountpoint"
fi

EFI_DEV=$(findmnt -no SOURCE "$EFI_MOUNT")
EFI_FSTYPE=$(findmnt -no FSTYPE "$EFI_MOUNT")
[ "$EFI_FSTYPE" = "vfat" ] || log WARN "EFI partition is $EFI_FSTYPE, expected vfat"

EFI_BASENAME=$(basename "$EFI_DEV")
PARENT=$(lsblk -no PKNAME "$EFI_DEV")
[ -n "$PARENT" ] || fail "lsblk could not find parent disk of $EFI_DEV"
DISK="/dev/$PARENT"
PARTNUM=$(cat "/sys/class/block/$EFI_BASENAME/partition")
log INFO "EFI: $EFI_DEV  Disk: $DISK  Part: $PARTNUM"

# ---------- 5. Detect ESP layout ----------
EFI_DIR=$(target_path /boot/efi/EFI)
log INFO "==== ESP LAYOUT ===="
ls -la "$EFI_DIR" 2>/dev/null || true

DETECTED_IDS=()
for cand in sles opensuse SUSE; do
  if [ -f "$EFI_DIR/$cand/grubx64.efi" ]; then
    log OK "Found $EFI_DIR/$cand/grubx64.efi"
    DETECTED_IDS+=("$cand")
  fi
done
[ "${#DETECTED_IDS[@]}" -gt 0 ] || log WARN "No grubx64.efi found in any expected vendor dir"

# Canonical id from os-release
OS_RELEASE=$(target_path /etc/os-release)
TARGET_ID=""
if [ -n "$FORCE_ID" ]; then
  TARGET_ID="$FORCE_ID"
elif [ -f "$OS_RELEASE" ]; then
  TARGET_ID=$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print $2}' "$OS_RELEASE")
  case "$TARGET_ID" in
    sles|sled)                              TARGET_ID="sles" ;;
    opensuse-leap|opensuse-tumbleweed|opensuse) TARGET_ID="opensuse" ;;
    *) log WARN "Unknown ID='$TARGET_ID' from os-release; defaulting to sles"
       TARGET_ID="sles" ;;
  esac
fi
log INFO "Canonical bootloader-id should be: $TARGET_ID"

# Drift warnings
for d in "${DETECTED_IDS[@]:-}"; do
  if [ -n "$d" ] && [ "$d" != "$TARGET_ID" ]; then
    log WARN "ESP has /EFI/$d but os-release says $TARGET_ID — leftover from migration"
  fi
done

# ---------- 6. Fallback binary check ----------
FALLBACK="$EFI_DIR/BOOT/BOOTX64.EFI"
EXPECTED_FALLBACK_SRC="$EFI_DIR/$TARGET_ID/grubx64.efi"
if [ -f "$FALLBACK" ]; then
  if [ -f "$EXPECTED_FALLBACK_SRC" ]; then
    if cmp -s "$FALLBACK" "$EXPECTED_FALLBACK_SRC" 2>/dev/null; then
      log OK "Fallback BOOTX64.EFI matches $TARGET_ID/grubx64.efi"
    else
      log WARN "Fallback BOOTX64.EFI does NOT match $TARGET_ID/grubx64.efi"
      log WARN "  Firmware that boots the fallback path will load a stale grub."
      log WARN "  This is the classic Leap->SLES migration symptom."
    fi
  else
    log WARN "Fallback exists but $EXPECTED_FALLBACK_SRC missing — cannot compare"
  fi
else
  log WARN "No fallback /EFI/BOOT/BOOTX64.EFI present"
fi

# ---------- 7. NVRAM audit ----------
log INFO "==== CURRENT NVRAM ===="
efibootmgr -v 2>&1 || log WARN "efibootmgr failed — efivars writable?"

# Highlight stale entries
STALE_FOUND=0
while IFS= read -r line; do
  if echo "$line" | grep -qE '(opensuse|openSUSE)'; then
    log WARN "Stale NVRAM entry references openSUSE: $line"
    STALE_FOUND=1
  fi
done < <(efibootmgr 2>/dev/null | grep -E '^Boot[0-9A-Fa-f]{4}' || true)
[ "$STALE_FOUND" -eq 0 ] && log OK "No openSUSE-tagged NVRAM entries detected"

# ---------- Read-only stop point ----------
if [ "$LIVE_MODE" -eq 1 ]; then
  log INFO "==== LIVE AUDIT COMPLETE ===="
  cat <<EOF

Summary:
  - Detected ESP vendor dirs: ${DETECTED_IDS[*]:-none}
  - Canonical id (os-release): $TARGET_ID
  - Fallback BOOTX64.EFI:      $([ -f "$FALLBACK" ] && echo "present" || echo "MISSING")
  - Stale NVRAM entries:       $([ "$STALE_FOUND" -eq 1 ] && echo "YES — repair recommended" || echo "none")

If repair is needed, boot a rescue ISO and run:
  ./efi-preflight-check.sh --fix --root /mnt/sysroot --id $TARGET_ID
EOF
  exit 0
fi

if [ "$FIX_MODE" -eq 0 ]; then
  log INFO "Offline read-only run complete. Re-run with --fix to apply repairs."
  exit 0
fi

# ============================================================
# FROM HERE ON: --fix mode (offline only)
# ============================================================

log FIX "==== APPLYING REPAIRS ===="

BACKUP="/tmp/efibootmgr-backup-$(date +%Y%m%d-%H%M%S).txt"
efibootmgr -v >"$BACKUP" 2>&1 || true
log FIX "NVRAM backed up to $BACKUP (live tmpfs — copy off if you care)"

# ---------- 8. Bind-mount virtual fs into chroot ----------
CHROOT_BIND_MOUNTED=()
bind_into() {
  local src="$1"
  local dst="$ROOT_MNT$1"
  [ -d "$src" ] || return 0
  if findmnt -n "$dst" >/dev/null; then return 0; fi
  mkdir -p "$dst"
  mount --rbind "$src" "$dst"
  mount --make-rslave "$dst" 2>/dev/null || true
  CHROOT_BIND_MOUNTED+=("$dst")
}
bind_into /dev
bind_into /proc
bind_into /sys
bind_into /run
if [ -d /sys/firmware/efi/efivars ] && \
   ! findmnt -n "$ROOT_MNT/sys/firmware/efi/efivars" >/dev/null; then
  mount -t efivarfs efivarfs "$ROOT_MNT/sys/firmware/efi/efivars" 2>/dev/null || true
fi
log OK "Virtual filesystems bind-mounted into $ROOT_MNT"

cleanup() {
  local m
  for m in $(printf '%s\n' "${CHROOT_BIND_MOUNTED[@]:-}" | tac); do
    [ -n "$m" ] || continue
    umount -R "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
  done
}
trap cleanup EXIT

# ---------- 9. Reinstall bootloader from inside chroot ----------
log FIX "Reinstalling bootloader inside chroot (id=$TARGET_ID, SB=off)"

chroot "$ROOT_MNT" /bin/bash -e <<CHROOT
  set -e
  export TARGET_ID="$TARGET_ID"

  echo "[chroot] Verifying grub2 package"
  rpm -q grub2-x86_64-efi >/dev/null 2>&1 || \
    echo "[chroot] WARN: grub2-x86_64-efi may be missing — proceeding anyway"

  echo "[chroot] Running grub2-install (Secure Boot off)"
  /usr/sbin/grub2-install \\
    --target=x86_64-efi \\
    --efi-directory=/boot/efi \\
    --bootloader-id="\$TARGET_ID" \\
    --recheck

  echo "[chroot] Regenerating /boot/grub2/grub.cfg"
  /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
CHROOT
log OK "Chroot bootloader install finished"

# ---------- 10. Verify and refresh fallback ----------
NEW_GRUB="$EFI_DIR/$TARGET_ID/grubx64.efi"
[ -f "$NEW_GRUB" ] || fail "$NEW_GRUB still missing after install — install failed"
log OK "$NEW_GRUB present"

mkdir -p "$EFI_DIR/BOOT"
if [ ! -f "$FALLBACK" ] || ! cmp -s "$NEW_GRUB" "$FALLBACK"; then
  cp -f "$NEW_GRUB" "$FALLBACK"
  log FIX "Refreshed fallback BOOTX64.EFI <- $TARGET_ID/grubx64.efi"
else
  log OK "Fallback already up to date"
fi

# ---------- 11. Clean stale NVRAM entries ----------
log FIX "Removing stale SUSE/SLES/openSUSE NVRAM entries"
mapfile -t STALE < <(efibootmgr | awk '
  /^Boot[0-9A-Fa-f]{4}/ {
    if ($0 ~ /sles/ || $0 ~ /SLES/ || $0 ~ /opensuse/ || $0 ~ /openSUSE/ || $0 ~ /SUSE/) {
      match($0, /^Boot[0-9A-Fa-f]{4}/)
      print substr($0, RSTART+4, 4)
    }
  }')
for id in "${STALE[@]:-}"; do
  [ -n "$id" ] || continue
  log FIX "Deleting Boot$id"
  efibootmgr -b "$id" -B >/dev/null || true
done

# ---------- 12. Create one good entry ----------
TARGET_UPPER=$(echo "$TARGET_ID" | tr '[:lower:]' '[:upper:]')
LOADER='\EFI\'"$TARGET_ID"'\grubx64.efi'
LABEL="$TARGET_UPPER-GRUB"

log FIX "Creating NVRAM entry: '$LABEL' -> $LOADER"
efibootmgr --create \
  --disk "$DISK" \
  --part "$PARTNUM" \
  --label "$LABEL" \
  --loader "$LOADER" >/dev/null

# Promote to first in BootOrder
NEW_ID=$(efibootmgr | awk -v lbl="$LABEL" '
  $0 ~ lbl {
    match($0, /^Boot[0-9A-Fa-f]{4}/)
    print substr($0, RSTART+4, 4)
    exit
  }')
if [ -n "$NEW_ID" ]; then
  CURRENT_ORDER=$(efibootmgr | awk '/^BootOrder:/ {print $2}')
  REST=$(echo "$CURRENT_ORDER" | tr ',' '\n' | grep -v "^$NEW_ID$" | paste -sd, || true)
  if [ -n "$REST" ]; then
    efibootmgr -o "$NEW_ID,$REST" >/dev/null
  else
    efibootmgr -o "$NEW_ID" >/dev/null
  fi
  log OK "BootOrder: $NEW_ID ($LABEL) is now first"
fi

# ---------- 13. Final state ----------
log INFO "==== FINAL NVRAM ===="
efibootmgr -v

cat <<EOF

==== DONE ====
Summary:
  - Bootloader id used:   $TARGET_ID
  - Loader registered:    $LOADER
  - NVRAM backup:         $BACKUP

Next steps:
  1. Unmount cleanly:
       cd /
       umount -R $ROOT_MNT
  2. Remove the USB live media.
  3. Reboot. Firmware should pick up the new "$LABEL" entry.
  4. If firmware still falls through to USB or wrong device:
       - Enter firmware setup; verify "$LABEL" is first in boot order.
       - Disable any "Boot Override" / "Removable Device First" sticky setting.
EOF
