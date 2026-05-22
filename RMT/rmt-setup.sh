#!/bin/bash
###############################################################################
# rmt-provision.sh
#
# Interactive setup wizard for a SUSE RMT (Repository Mirroring Tool) server.
# Targets bare/fresh SLES 15 SP7 (also works on SP6). Installs RMT, then walks
# the operator through environment-specific choices:
#
#   1. ROLE          connected-standalone | external-for-airgap | airgapped-internal
#   2. BIND ADDRESS  specific private IP | all interfaces   (nginx listen)
#   3. HTTPS CERT    self-signed | Let's Encrypt | bring-your-own
#   4. FIREWALLD     enable+open ports | disable | leave as-is
#   5. FIPS          enable (reboot required) | leave as-is
#
# It does NOT script the SCC organization-credentials + database step: that is
# done by the supported `yast2 rmt` module, which this script launches at the
# end (or tells you to run). SCC credentials are sensitive and the YaST module
# is the supported path.
#
# Must run as root on the RMT host.
###############################################################################

set -uo pipefail

###############################################################################
# Output helpers
###############################################################################
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[0;90m'
    C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YEL=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_CYAN=$'\033[1;36m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_BLUE=""; C_GREEN=""; C_YEL=""; C_RED=""; C_CYAN=""
fi
info()  { echo "${C_BLUE}==>${C_RESET} $*"; }
ok()    { echo "${C_GREEN}[OK]${C_RESET} $*"; }
warn()  { echo "${C_YEL}[!]${C_RESET} $*" >&2; }
err()   { echo "${C_RED}[x]${C_RESET} $*" >&2; }
die()   { err "$*"; exit 1; }
hr()    { echo "${C_DIM}--------------------------------------------------------------${C_RESET}"; }
banner(){ echo; hr; echo "${C_BOLD}$*${C_RESET}"; hr; }

ask() { # ask "Question" "default" -> echoes answer
    local q="$1" def="${2:-}" reply
    if [[ -n "$def" ]]; then read -rp "$q [$def]: " reply; echo "${reply:-$def}"
    else read -rp "$q: " reply; echo "$reply"; fi
}
confirm() { # confirm "Question" "Y|N"
    local q="$1" def="${2:-N}" reply ps="[y/N]"
    [[ "$def" == "Y" ]] && ps="[Y/n]"
    read -rp "$q $ps " reply; reply="${reply:-$def}"
    [[ "$reply" =~ ^[Yy]$ ]]
}
# choose "Prompt" opt1 opt2 ...  -> sets REPLY_CHOICE + REPLY_INDEX
REPLY_CHOICE=""; REPLY_INDEX=0
choose() {
    local prompt="$1"; shift; local -a opts=("$@") i n
    echo "$prompt" >&2
    for i in "${!opts[@]}"; do printf "  %d) %s\n" $((i+1)) "${opts[$i]}" >&2; done
    while true; do
        read -rp "Selection: " n
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#opts[@]} )); then
            REPLY_CHOICE="${opts[$((n-1))]}"; REPLY_INDEX=$n; return 0
        fi
        warn "Invalid selection."
    done
}

###############################################################################
# Globals filled in by the wizard
###############################################################################
ROLE=""
BIND_ADDR=""           # "0.0.0.0" or a specific IP
SERVER_FQDN=""
CERT_MODE=""           # selfsigned | letsencrypt | existing
EXISTING_CERT=""; EXISTING_KEY=""
FW_ACTION=""           # enable | disable | leave
OPEN_HTTP="no"         # open port 80 too?
DO_FIPS="no"
REBOOT_NEEDED="no"

RMT_PKGS=(rmt-server yast2-rmt nginx mariadb)
RMT_CONF="/etc/rmt.conf"
SSL_DIR="/etc/rmt/ssl"
REPO_DIR="/var/lib/rmt/public/repo"

###############################################################################
# Preflight
###############################################################################
preflight() {
    [[ $EUID -eq 0 ]] || die "Run as root."
    [[ -f /etc/os-release ]] || die "Cannot read /etc/os-release."
    . /etc/os-release
    case "${ID:-}" in
        sles|sle-micro|sled) : ;;
        *) warn "This script targets SLES. Detected ID='${ID:-unknown}'. Continuing, but YMMV." ;;
    esac
    info "Detected: ${PRETTY_NAME:-unknown}"
    command -v zypper >/dev/null || die "zypper not found -- this is not a SUSE system."
}

###############################################################################
# Step 1: role
###############################################################################
wizard_role() {
    banner "1. RMT server role"
    cat <<EOF
  connected-standalone : pulls from SCC AND serves clients directly (typical)
  external-for-airgap  : pulls from SCC, you 'rmt-cli export' for transport in
  airgapped-internal   : offline; you 'rmt-cli import' here; serves air-gap clients
EOF
    choose "Which role does THIS server play?" \
        "connected-standalone" "external-for-airgap" "airgapped-internal"
    ROLE="$REPLY_CHOICE"
    ok "Role: $ROLE"
}

###############################################################################
# Step 2: bind address (nginx listen)
###############################################################################
detect_ips() {
    ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
}
wizard_bind() {
    banner "2. Network bind address"
    local -a ips=()
    while IFS= read -r x; do [[ -n "$x" ]] && ips+=("$x"); done < <(detect_ips)

    echo "Detected global IPv4 addresses:"
    local i
    for i in "${!ips[@]}"; do printf "   - %s\n" "${ips[$i]}"; done
    echo

    # Default steer: external/airgapped -> a specific (private) IP; standalone -> all
    local default_hint="all interfaces"
    [[ "$ROLE" == "external-for-airgap" ]] && default_hint="a specific private IP"

    local -a opts=("All interfaces (0.0.0.0)")
    for i in "${!ips[@]}"; do opts+=("Bind to ${ips[$i]}"); done
    info "Suggested for role '$ROLE': $default_hint"
    choose "Where should nginx listen?" "${opts[@]}"

    if [[ "$REPLY_INDEX" == "1" ]]; then
        BIND_ADDR="0.0.0.0"
    else
        BIND_ADDR="${ips[$((REPLY_INDEX-2))]}"
    fi
    ok "nginx will listen on: $BIND_ADDR"

    # FQDN (used for cert CN + client regurl). Default to hostname -f.
    local hn; hn="$(hostname -f 2>/dev/null || hostname)"
    SERVER_FQDN="$(ask "Server FQDN clients will use (must match the cert CN)" "$hn")"
    ok "Server FQDN: $SERVER_FQDN"
}

###############################################################################
# Step 3: HTTPS certificate strategy
###############################################################################
wizard_cert() {
    banner "3. HTTPS certificate"
    if [[ "$ROLE" == "airgapped-internal" ]]; then
        warn "Air-gapped role: Let's Encrypt is not viable (no inbound reachability)."
    fi
    cat <<EOF
  self-signed   : RMT/YaST generates its own CA + server cert (good for air-gap)
                  Clients must trust the CA (served at https://${SERVER_FQDN}/rmt.crt)
  letsencrypt   : public CA via certbot; needs a public FQDN + inbound port 80
  existing      : you already have a cert + key from your own/org CA
EOF
    choose "Certificate strategy?" "self-signed" "letsencrypt" "existing"
    CERT_MODE="$REPLY_CHOICE"

    case "$CERT_MODE" in
        existing)
            EXISTING_CERT="$(ask "Path to server certificate (PEM, full chain)")"
            EXISTING_KEY="$(ask "Path to server private key (PEM)")"
            [[ -f "$EXISTING_CERT" ]] || die "Cert not found: $EXISTING_CERT"
            [[ -f "$EXISTING_KEY"  ]] || die "Key not found: $EXISTING_KEY"
            # quick sanity: modulus match
            local cm km
            cm=$(openssl x509 -noout -modulus -in "$EXISTING_CERT" 2>/dev/null | openssl md5)
            km=$(openssl rsa  -noout -modulus -in "$EXISTING_KEY"  2>/dev/null | openssl md5)
            if [[ -n "$cm" && "$cm" == "$km" ]]; then ok "Cert and key match."
            else warn "Could not confirm cert/key match (non-RSA key?). Double-check before relying on it."; fi
            ;;
        letsencrypt)
            [[ "$ROLE" == "airgapped-internal" ]] && warn "You picked Let's Encrypt on an air-gapped role -- this will not work offline."
            OPEN_HTTP="yes"   # certbot http-01 needs port 80
            info "Let's Encrypt requires:"
            info "  - $SERVER_FQDN resolves publicly to THIS host"
            info "  - inbound TCP 80 reachable from the internet (for HTTP-01 renewal)"
            ;;
        selfsigned)
            info "YaST will generate the CA + server cert during configuration."
            info "After setup, distribute the CA to clients (https://${SERVER_FQDN}/rmt.crt)"
            info "or run rmt-client-setup on each client."
            ;;
    esac
    ok "Certificate strategy: $CERT_MODE"
}

###############################################################################
# Step 4: firewalld
###############################################################################
wizard_firewall() {
    banner "4. Firewall (firewalld)"
    local state="not installed"
    if command -v firewall-cmd >/dev/null 2>&1; then
        state="$(systemctl is-active firewalld 2>/dev/null || echo inactive)"
    fi
    info "firewalld current state: $state"
    choose "Firewall action?" \
        "Enable firewalld and open RMT ports" \
        "Disable firewalld" \
        "Leave as-is"
    case "$REPLY_INDEX" in
        1) FW_ACTION="enable"
           if [[ "$CERT_MODE" == "letsencrypt" ]]; then OPEN_HTTP="yes"; fi
           if [[ "$OPEN_HTTP" != "yes" ]]; then
               confirm "Also open port 80 (HTTP redirect / client convenience)?" "N" && OPEN_HTTP="yes"
           fi
           ;;
        2) FW_ACTION="disable" ;;
        3) FW_ACTION="leave" ;;
    esac
    if [[ "$FW_ACTION" == "enable" ]]; then
        ok "Firewall: enable (open 443$( [[ "$OPEN_HTTP" == yes ]] && echo ', 80'))"
    else
        ok "Firewall: $FW_ACTION"
    fi
}

###############################################################################
# Step 5: FIPS
###############################################################################
wizard_fips() {
    banner "5. FIPS 140-3 mode"
    local cur="disabled"
    [[ "$(sysctl -n crypto.fips_enabled 2>/dev/null || echo 0)" == "1" ]] && cur="enabled"
    info "FIPS currently: $cur"
    cat <<EOF
  ${C_YEL}Note:${C_RESET} FIPS is restrictive and requires a REBOOT to take effect.
  It enforces validated crypto; some tooling may need adjustment afterward.
  Only enable if your compliance rules require it.
EOF
    if confirm "Enable FIPS mode?" "N"; then
        DO_FIPS="yes"; REBOOT_NEEDED="yes"
    fi
    ok "FIPS: $DO_FIPS"
}

###############################################################################
# Summary + confirm
###############################################################################
wizard_summary() {
    banner "Review"
    cat <<EOF
  Role:              $ROLE
  nginx bind:        $BIND_ADDR
  Server FQDN:       $SERVER_FQDN
  Certificate:       $CERT_MODE$( [[ "$CERT_MODE" == existing ]] && echo " ($EXISTING_CERT)")
  Firewall:          $FW_ACTION$( [[ "$FW_ACTION" == enable ]] && echo " (open 443$( [[ "$OPEN_HTTP" == yes ]] && echo ', 80'))")
  FIPS:              $DO_FIPS$( [[ "$DO_FIPS" == yes ]] && echo " (reboot required)")
  Packages:          ${RMT_PKGS[*]}
EOF
    hr
    confirm "Proceed with these settings?" "Y" || { warn "Aborted by user."; exit 0; }
}

###############################################################################
# Apply steps
###############################################################################
apply_packages() {
    banner "Installing RMT packages"
    # /tmp sizing caution (mirroring writes large temp files)
    local tmp_kb; tmp_kb=$(df -kP /tmp | awk 'NR==2{print $4}')
    if [[ -n "$tmp_kb" && "$tmp_kb" -lt 5242880 ]]; then
        warn "/tmp has <5GB free. RMT mirroring writes large temp files there; consider enlarging /tmp."
    fi
    info "zypper install ${RMT_PKGS[*]}"
    if ! zypper --non-interactive install "${RMT_PKGS[@]}"; then
        die "Package install failed. Ensure repositories are available (registration / local ISO)."
    fi
    ok "Packages installed."
}

apply_fips() {
    [[ "$DO_FIPS" == "yes" ]] || return 0
    banner "Enabling FIPS mode"
    info "Installing FIPS pattern + crypto-policies-scripts"
    zypper --non-interactive install -t pattern patterns-base-fips 2>/dev/null \
        || zypper --non-interactive install patterns-base-fips 2>/dev/null \
        || warn "Could not install patterns-base-fips (may already be present)."
    zypper --non-interactive install crypto-policies-scripts 2>/dev/null || true
    if command -v fips-mode-setup >/dev/null 2>&1; then
        fips-mode-setup --enable || warn "fips-mode-setup --enable returned non-zero."
        ok "FIPS enabled. A REBOOT is required before it takes effect."
        warn "SP7 note: if SSH fails after reboot with 'PRNG is not seeded', see SUSE FIPS docs."
    else
        warn "fips-mode-setup not found; FIPS not enabled."
    fi
}

apply_existing_cert() {
    [[ "$CERT_MODE" == "existing" ]] || return 0
    banner "Installing provided certificate"
    if ! install -d -m 0755 "$SSL_DIR"; then
        warn "Could not create $SSL_DIR (is rmt-server installed yet?). Place certs there manually:"
        warn "  cp '$EXISTING_CERT' $SSL_DIR/rmt-server.crt"
        warn "  cp '$EXISTING_KEY'  $SSL_DIR/rmt-server.key   (chmod 600)"
        return 0
    fi
    if install -m 0644 "$EXISTING_CERT" "$SSL_DIR/rmt-server.crt" \
       && install -m 0600 "$EXISTING_KEY" "$SSL_DIR/rmt-server.key"; then
        ok "Copied to $SSL_DIR/rmt-server.{crt,key}"
        warn "YaST may still want to generate its own CA; when it offers, decline cert"
        warn "regeneration and keep these files, OR point nginx at them post-setup."
    else
        warn "Failed to copy cert/key into $SSL_DIR. Place them manually after RMT install."
    fi
}

apply_letsencrypt() {
    [[ "$CERT_MODE" == "letsencrypt" ]] || return 0
    banner "Let's Encrypt (certbot)"
    info "Installing certbot"
    zypper --non-interactive install certbot 2>/dev/null || warn "Could not install certbot from current repos."
    cat <<EOF
${C_CYAN}Manual step required after this script (so RMT/nginx config exists first):${C_RESET}
  1. Ensure $SERVER_FQDN resolves to this host and inbound TCP 80 is open.
  2. Obtain a cert:
       certbot certonly --standalone -d $SERVER_FQDN --agree-tos -m <you@example.com>
  3. Point nginx at:
       /etc/letsencrypt/live/$SERVER_FQDN/fullchain.pem
       /etc/letsencrypt/live/$SERVER_FQDN/privkey.pem
  4. Test renewal:  certbot renew --dry-run
EOF
}

apply_firewall() {
    banner "Firewall"
    case "$FW_ACTION" in
        enable)
            command -v firewall-cmd >/dev/null 2>&1 || zypper --non-interactive install firewalld
            systemctl enable --now firewalld
            firewall-cmd --permanent --add-service=https
            [[ "$OPEN_HTTP" == "yes" ]] && firewall-cmd --permanent --add-service=http
            firewall-cmd --reload
            ok "firewalld enabled; opened 443$( [[ "$OPEN_HTTP" == yes ]] && echo ' + 80')."
            ;;
        disable)
            systemctl disable --now firewalld 2>/dev/null || true
            ok "firewalld disabled."
            ;;
        leave) info "Firewall left as-is." ;;
    esac
}

# nginx bind: write a drop-in that constrains the listen address, if not 'all'.
apply_bind() {
    banner "nginx listen address"
    if [[ "$BIND_ADDR" == "0.0.0.0" ]]; then
        info "Listening on all interfaces (default). No nginx override written."
        return 0
    fi
    # RMT's nginx vhost is generated by YaST/rmt; we add a server-name + note for the operator.
    # The robust, supported way to constrain the bind is an nginx drop-in that the operator
    # reviews. We DON'T blindly rewrite RMT's generated vhost.
    cat <<EOF
${C_CYAN}To bind RMT's nginx to $BIND_ADDR only:${C_RESET}
  After 'yast2 rmt' generates the RMT vhost (typically /etc/nginx/vhosts.d/rmt*.conf
  or /etc/nginx/conf.d/), edit the 'listen' directives to:
       listen $BIND_ADDR:443 ssl;
       listen $BIND_ADDR:80;     # if HTTP enabled
  then:  nginx -t && systemctl reload nginx
${C_DIM}Reason: RMT's vhost is auto-generated; editing it AFTER YaST avoids it being
overwritten. This script flags the change rather than racing YaST.${C_RESET}
EOF
    warn "nginx bind to $BIND_ADDR flagged as a post-YaST manual edit (see above)."
}

run_yast_rmt() {
    banner "RMT configuration (yast2 rmt)"
    cat <<EOF
The supported initial configuration runs now via the YaST RMT module. It will:
  - prompt for your SCC organization credentials (from https://scc.suse.com)
  - set up the MariaDB database
  - generate the CA + server SSL certificate (for self-signed mode)
  - write $RMT_CONF and configure nginx

EOF
    if [[ "$ROLE" == "airgapped-internal" ]]; then
        warn "Air-gapped internal role: you typically do NOT enter SCC creds here."
        warn "Instead you'll 'rmt-cli import' data exported from the external RMT."
        warn "You may still run 'yast2 rmt' to set up DB + certs; skip SCC mirroring."
    fi
    if confirm "Launch 'yast2 rmt' now?" "Y"; then
        yast2 rmt || warn "yast2 rmt exited non-zero; you can re-run it anytime."
    else
        info "Skipped. Run 'yast2 rmt' later to finish configuration."
    fi
}

post_summary() {
    banner "Done"
    cat <<EOF
Next steps / reminders:
  * Finish/verify config:        yast2 rmt   (if you skipped it)
  * Reload after conf edits:     systemctl restart rmt-server
  * Sync product catalog:        rmt-cli sync
  * Pick products to mirror:     (your rmt_menu.sh / rmt-cli products enable)
  * Mirror:                      rmt-cli mirror
  * Repo data dir:               $REPO_DIR  (size for ~1.5x enabled repo size)
EOF
    [[ "$CERT_MODE" == "selfsigned" ]] && echo "  * Client trust (self-signed): clients run rmt-client-setup https://$SERVER_FQDN"
    [[ "$CERT_MODE" == "letsencrypt" ]] && echo "  * Finish Let's Encrypt steps printed above, then point nginx at the LE cert."
    [[ "$BIND_ADDR" != "0.0.0.0" ]] && echo "  * Apply the nginx listen=$BIND_ADDR edit noted above (post-YaST)."
    case "$ROLE" in
      external-for-airgap) echo "  * Export for air-gap:        rmt-cli export <path>  (carry to internal RMT)";;
      airgapped-internal)  echo "  * Import on this server:     rmt-cli import <path>  (from external RMT export)";;
    esac
    if [[ "$REBOOT_NEEDED" == "yes" ]]; then
        echo
        warn "FIPS was enabled -- REBOOT required before it takes effect."
        confirm "Reboot now?" "N" && reboot
    fi
}

###############################################################################
# Main
###############################################################################
main() {
    preflight
    banner "RMT Server Setup Wizard"
    echo "This wizard installs and configures an RMT server for your environment."
    echo "It will ask about role, network bind, TLS cert, firewall, and FIPS."
    echo

    wizard_role
    wizard_bind
    wizard_cert
    wizard_firewall
    wizard_fips
    wizard_summary

    apply_packages
    apply_fips
    apply_existing_cert
    apply_letsencrypt
    apply_firewall
    apply_bind
    run_yast_rmt
    post_summary
}

main "$@"
