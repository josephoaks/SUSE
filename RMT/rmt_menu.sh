#!/bin/bash
###############################################################################
# rmt_menu.sh  (dynamic, tree-aware rewrite)
#
# Written by: Joseph Oaks (15 Nov 2023)
#
# Originally written as a hard-coded product picker.
#
# This rewrite discovers everything live from the RMT's own database,
# so it presents only the products that THIS RMT is entitled to.
#
# Menu flow:   Product name  ->  Architecture  ->  Version  ->  Module tree
# The module tree mirrors the SCC hierarchy shown by `SUSEConnect -l`. Selecting
# any module automatically pulls in its required parent chain. Final selection
# is enabled by product ID and mirrored.
#
# Key properties:
#   * Reads the RMT MariaDB ONCE at startup, holds it in memory for the run,
#     persists NOTHING to disk -- always current, never a stale cache.
#   * Enables by numeric product ID (unambiguous); shows product strings + names.
#   * Auto-includes the ancestor chain (a child cannot mirror without parents).
#   * Only shows released products (no betas) and only bases that have a tree.
#
# Must run as root on the RMT server (needs local DB access + rmt-cli).
###############################################################################

set -uo pipefail

###############################################################################
# Config (override via environment if needed)
###############################################################################
DB_NAME="${RMT_DB_NAME:-rmt}"
RELEASE_STAGE="${RMT_RELEASE_STAGE:-released}"   # 'released' hides betas
AUTO_MIRROR="${RMT_AUTO_MIRROR:-ask}"            # ask | yes | no
MYSQL_BIN="$(command -v mariadb 2>/dev/null || command -v mysql 2>/dev/null)"
RMT_CLI="$(command -v rmt-cli 2>/dev/null)"

###############################################################################
# Output helpers
###############################################################################
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[0;90m'
    C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YEL=$'\033[1;33m'; C_RED=$'\033[1;31m'
    C_CYAN=$'\033[1;36m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_BLUE=""; C_GREEN=""; C_YEL=""; C_RED=""; C_CYAN=""
fi
info() { echo "${C_BLUE}==>${C_RESET} $*"; }
ok()   { echo "${C_GREEN}[OK]${C_RESET} $*"; }
warn() { echo "${C_YEL}[!]${C_RESET} $*" >&2; }
err()  { echo "${C_RED}[x]${C_RESET} $*" >&2; }
die()  { err "$*"; exit 1; }
hr()   { echo "${C_DIM}--------------------------------------------------------------${C_RESET}"; }

###############################################################################
# Preflight checks
###############################################################################
preflight() {
    [[ $EUID -eq 0 ]] || warn "Not running as root; DB access may fail."
    [[ -n "$MYSQL_BIN" ]] || die "No 'mariadb'/'mysql' client found."
    [[ -n "$RMT_CLI" ]]   || die "'rmt-cli' not found -- run this on the RMT server."
    "$MYSQL_BIN" "$DB_NAME" -N -e "SELECT 1;" >/dev/null 2>&1 \
        || die "Cannot query database '$DB_NAME'. Run as root on the RMT (or set RMT_DB_NAME)."
    local n
    n=$("$MYSQL_BIN" "$DB_NAME" -N -e \
        "SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema='$DB_NAME' AND table_name IN ('products','products_extensions');" 2>/dev/null)
    [[ "$n" == "2" ]] || die "RMT schema not found (need products + products_extensions)."
}

# Tab-separated, no header, batch mode (NULLs come back empty-ish; we coalesce in SQL)
dbq() { "$MYSQL_BIN" "$DB_NAME" -N --batch -e "$1" 2>/dev/null; }

###############################################################################
# In-memory catalog (populated once at startup; discarded on exit)
###############################################################################
declare -A P_IDENT P_NAME P_VER P_ARCH P_STR P_FREE P_MIRRORED
# Tree maps are scoped per-root to keep keys unique across bases:
declare -A CHILDREN     # "root:parent_id" -> " c1 c2 c3"
declare -A REC          # "root:child_id"  -> 0|1 (recommended)
declare -A PARENT       # "root:child_id"  -> parent_id
declare -A SELECTED     # child_id -> 1   (reset per base)

load_products() {
    info "Reading product catalog from RMT database (one-time)..."
    local id ident name ver arch free
    while IFS=$'\t' read -r id ident name ver arch free; do
        [[ -z "$id" ]] && continue
        P_IDENT["$id"]="$ident"; P_NAME["$id"]="$name"
        P_VER["$id"]="$ver";     P_ARCH["$id"]="$arch"
        P_FREE["$id"]="$free";   P_MIRRORED["$id"]=0
        if [[ -n "$arch" ]]; then P_STR["$id"]="${ident}/${ver}/${arch}"
        else                      P_STR["$id"]="${ident}/${ver}"; fi
    done < <(dbq "SELECT id, identifier, name, version, COALESCE(arch,''), COALESCE(free,1) FROM products;")
    ok "Loaded ${#P_IDENT[@]} products."
}

# Mark which products are currently mirrored, per rmt-cli (authoritative).
load_mirror_status() {
    local id rest mirror
    while IFS=, read -r id _n _v _a _s _stage mirror _last; do
        [[ "$id" == "ID" || -z "$id" ]] && continue
        [[ "$mirror" == "true" ]] && P_MIRRORED["$id"]=1
    done < <("$RMT_CLI" products list --all --csv 2>/dev/null)
}

###############################################################################
# Level 1: distinct base product NAMES that have a module tree (released only)
###############################################################################
menu_names() {
    dbq "
        SELECT DISTINCT p.name
        FROM products p
        JOIN products_extensions pe ON pe.root_product_id = p.id
        WHERE p.product_type = 'base'
          AND p.release_stage = '${RELEASE_STAGE}'
          AND COALESCE(p.arch,'') <> ''
        ORDER BY p.name;"
}

###############################################################################
# Level 2: architectures available for a given base name
###############################################################################
menu_arches_for_name() {
    local name="$1"
    dbq "
        SELECT DISTINCT p.arch
        FROM products p
        JOIN products_extensions pe ON pe.root_product_id = p.id
        WHERE p.product_type = 'base'
          AND p.release_stage = '${RELEASE_STAGE}'
          AND p.name = '$(sql_escape "$name")'
          AND COALESCE(p.arch,'') <> ''
        ORDER BY p.arch;"
}

###############################################################################
# Level 3: versions available for a given base name + arch
# Returns: id \t version   (so we can map the chosen version straight to a root id)
###############################################################################
menu_versions_for_name_arch() {
    local name="$1" arch="$2"
    dbq "
        SELECT p.id, p.version
        FROM products p
        JOIN products_extensions pe ON pe.root_product_id = p.id
        WHERE p.product_type = 'base'
          AND p.release_stage = '${RELEASE_STAGE}'
          AND p.name = '$(sql_escape "$name")'
          AND p.arch = '$(sql_escape "$arch")'
        GROUP BY p.id, p.version
        ORDER BY p.version;"
}

# Minimal SQL string escaping for the single-quoted literals above
sql_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\'/\\\'}"; printf '%s' "$s"; }

###############################################################################
# Load the full module tree for one root product id into the tree maps
###############################################################################
load_tree_for_root() {
    local root="$1" parent child rec k
    # wipe any previous root's edges
    for k in "${!CHILDREN[@]}"; do [[ "$k" == "$root:"* ]] && unset 'CHILDREN[$k]'; done
    for k in "${!REC[@]}";      do [[ "$k" == "$root:"* ]] && unset 'REC[$k]'; done
    for k in "${!PARENT[@]}";   do [[ "$k" == "$root:"* ]] && unset 'PARENT[$k]'; done
    while IFS=$'\t' read -r parent child rec; do
        [[ -z "$parent" ]] && continue
        CHILDREN["$root:$parent"]="${CHILDREN["$root:$parent"]:-} $child"
        REC["$root:$child"]="$rec"
        PARENT["$root:$child"]="$parent"
    done < <(dbq "
        SELECT pe.product_id, pe.extension_id, pe.recommended
        FROM products_extensions pe
        JOIN products ext ON ext.id = pe.extension_id
        WHERE pe.root_product_id = $root
          AND ext.release_stage = '${RELEASE_STAGE}'
        ORDER BY pe.product_id, pe.extension_id;")
}

###############################################################################
# Ancestor inclusion: select a node + every parent up to the root
###############################################################################
select_with_ancestors() {
    local root="$1" node="$2"
    SELECTED["$node"]=1
    local p
    while true; do
        p="${PARENT["$root:$node"]:-}"
        [[ -z "$p" || "$p" == "$root" ]] && break
        SELECTED["$p"]=1
        node="$p"
    done
}

# Deselect a node + everything beneath it (can't keep a child without its parent)
deselect_with_descendants() {
    local root="$1" node="$2"
    unset 'SELECTED[$node]'
    local c
    for c in ${CHILDREN["$root:$node"]:-}; do
        [[ -n "${SELECTED[$c]:-}" ]] && deselect_with_descendants "$root" "$c"
    done
}

###############################################################################
# Render the tree (indented), showing selection + recommended + regcode markers
###############################################################################
# Globals used to map menu numbers -> node ids for the current render
declare -a TREE_ORDER
render_tree() {
    local root="$1"
    TREE_ORDER=()
    _render_node "$root" "$root" 0
}
_render_node() {
    local root="$1" node="$2" depth="$3"
    local c
    for c in ${CHILDREN["$root:$node"]:-}; do
        TREE_ORDER+=("$c")
        local idx="${#TREE_ORDER[@]}"
        local indent=""; local d=0
        while (( d < depth )); do indent+="    "; ((d++)); done
        # markers
        local mark="[ ]"
        [[ -n "${SELECTED[$c]:-}" ]] && mark="${C_GREEN}[x]${C_RESET}"
        local recflag=""
        [[ "${REC["$root:$c"]:-0}" == "1" ]] && recflag=" ${C_CYAN}(recommended)${C_RESET}"
        local regflag=""
        [[ "${P_FREE[$c]:-1}" == "0" ]] && regflag=" ${C_YEL}\$regcode${C_RESET}"
        local mirroredflag=""
        [[ "${P_MIRRORED[$c]:-0}" == "1" ]] && mirroredflag=" ${C_DIM}(mirrored)${C_RESET}"
        printf "  %2d) %s %s%s%s%s%s\n" \
            "$idx" "$mark" "$indent" "${P_NAME[$c]}" "$recflag" "$regflag" "$mirroredflag"
        # recurse
        _render_node "$root" "$c" $((depth+1))
    done
}

###############################################################################
# Interactive tree walk for one chosen base
###############################################################################
walk_tree() {
    local root="$1"
    SELECTED=()                       # reset selection for this base
    SELECTED["$root"]=1               # base itself is always included

    while true; do
        hr
        echo "${C_BOLD}${P_NAME[$root]} ${P_VER[$root]} ${P_ARCH[$root]}${C_RESET}"
        echo "${C_DIM}Base product (always included): ${P_STR[$root]}${C_RESET}"
        hr
        echo "Choose individual channels with comma-separated numbers (e.g. 1,2,4,11)."
        echo "${C_DIM}Selecting a child auto-selects its parents; deselecting drops anything nested under it.${C_RESET}"
        echo
        render_tree "$root"
        echo
        echo "  ${C_BOLD}a${C_RESET}) select all recommended    ${C_BOLD}A${C_RESET}) select ALL"
        echo "  ${C_BOLD}c${C_RESET}) clear selections"
        echo "  ${C_BOLD}d${C_RESET}) DONE - review & enable     ${C_BOLD}q${C_RESET}) cancel this base"
        echo
        read -rp "Choice: " choice

        case "$choice" in
            *[0-9]*)
                # Accept a comma-separated list: "1,2,4" or "1, 2, 4".
                # Each number is toggled in turn (select pulls ancestors,
                # deselect cascades to descendants).
                local token nidx node bad=()
                local -a fields=()
                # Split on commas WITHOUT leaking IFS into the tree-walk helpers
                # (child lists are space-separated, so IFS must be normal there).
                IFS=',' read -ra fields <<< "$choice"
                for token in "${fields[@]}"; do
                    # trim surrounding whitespace
                    token="${token#"${token%%[![:space:]]*}"}"
                    token="${token%"${token##*[![:space:]]}"}"
                    [[ -z "$token" ]] && continue
                    if [[ ! "$token" =~ ^[0-9]+$ ]]; then
                        bad+=("$token"); continue
                    fi
                    nidx="$token"
                    if (( nidx >= 1 && nidx <= ${#TREE_ORDER[@]} )); then
                        node="${TREE_ORDER[$((nidx-1))]}"
                        if [[ -n "${SELECTED[$node]:-}" ]]; then
                            deselect_with_descendants "$root" "$node"
                        else
                            select_with_ancestors "$root" "$node"
                        fi
                    else
                        bad+=("$token")
                    fi
                done
                (( ${#bad[@]} > 0 )) && warn "Ignored invalid/out-of-range: ${bad[*]}"
                ;;
            a)  # all recommended (+ their ancestors)
                local k cid
                for k in "${!REC[@]}"; do
                    [[ "$k" == "$root:"* && "${REC[$k]}" == "1" ]] || continue
                    cid="${k#$root:}"
                    select_with_ancestors "$root" "$cid"
                done
                ;;
            A)  # everything in this tree
                local k cid
                for k in "${!PARENT[@]}"; do
                    [[ "$k" == "$root:"* ]] || continue
                    cid="${k#$root:}"
                    SELECTED["$cid"]=1
                done
                ;;
            c)  SELECTED=(); SELECTED["$root"]=1 ;;
            d)  return 0 ;;
            q)  return 1 ;;
            *)  warn "Unrecognized choice." ;;
        esac
    done
}

###############################################################################
# Confirm + enable + mirror the current selection
###############################################################################
finalize_selection() {
    local root="$1"
    # Build ordered, deduped ID list (root first, then the rest)
    local -a ids=( "$root" )
    local id
    for id in "${!SELECTED[@]}"; do
        [[ "$id" == "$root" ]] && continue
        ids+=("$id")
    done

    hr
    info "Selected products to enable:"
    for id in "${ids[@]}"; do
        local reg=""
        [[ "${P_FREE[$id]:-1}" == "0" ]] && reg=" ${C_YEL}(needs regcode on client)${C_RESET}"
        printf "   ${C_GREEN}+${C_RESET} %-46s %s%s\n" "${P_STR[$id]}" "${P_NAME[$id]}" "$reg"
    done
    echo
    echo "${C_DIM}rmt-cli will be called with these product IDs:${C_RESET}"
    echo "   ${ids[*]}"
    hr

    read -rp "Enable these now? [Y/n] " yn
    yn="${yn:-Y}"
    [[ "$yn" =~ ^[Yy]$ ]] || { warn "Skipped."; return 0; }

    info "Enabling..."
    if "$RMT_CLI" products enable "${ids[@]}"; then
        ok "Products enabled."
    else
        warn "rmt-cli reported an error enabling one or more products."
    fi

    # Mirror
    local do_mirror="$AUTO_MIRROR"
    if [[ "$do_mirror" == "ask" ]]; then
        read -rp "Run 'rmt-cli mirror' now? (can take a long time) [y/N] " m
        [[ "${m:-N}" =~ ^[Yy]$ ]] && do_mirror="yes" || do_mirror="no"
    fi
    if [[ "$do_mirror" == "yes" ]]; then
        info "Mirroring (this may take a while)..."
        "$RMT_CLI" mirror || warn "Mirror reported errors -- review output."
    else
        warn "Skipped mirror. Run 'rmt-cli mirror' when ready."
    fi
}

###############################################################################
# select-from-list helper: prints a numbered menu, reads a choice, echoes pick.
# Usage: choose "Prompt" "${array[@]}"  -> sets global REPLY_CHOICE
###############################################################################
REPLY_CHOICE=""
choose() {
    local prompt="$1"; shift
    local -a opts=( "$@" )
    local i
    echo "$prompt" >&2
    for i in "${!opts[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${opts[$i]}" >&2
    done
    printf "  %2d) %s\n" $(( ${#opts[@]} + 1 )) "Exit" >&2
    local n
    while true; do
        read -rp "Selection: " n
        if [[ "$n" =~ ^[0-9]+$ ]]; then
            if (( n >= 1 && n <= ${#opts[@]} )); then
                REPLY_CHOICE="${opts[$((n-1))]}"; return 0
            elif (( n == ${#opts[@]} + 1 )); then
                REPLY_CHOICE="__EXIT__"; return 0
            fi
        fi
        warn "Invalid selection."
    done
}

###############################################################################
# Main flow
###############################################################################
main() {
    preflight
    load_products
    load_mirror_status

    while true; do
        # ---- Level 1: product name ----
        local -a names=()
        while IFS= read -r line; do names+=("$line"); done < <(menu_names)
        (( ${#names[@]} > 0 )) || die "No tree-bearing released base products found in this RMT."

        hr; info "Select a product"; hr
        choose "Products available on this RMT:" "${names[@]}"
        [[ "$REPLY_CHOICE" == "__EXIT__" ]] && { echo "Exiting."; exit 0; }
        local chosen_name="$REPLY_CHOICE"

        # ---- Level 2: architecture ----
        local -a arches=()
        while IFS= read -r line; do arches+=("$line"); done < <(menu_arches_for_name "$chosen_name")
        hr; info "Architecture for: ${C_BOLD}${chosen_name}${C_RESET}"; hr
        choose "Available architectures:" "${arches[@]}"
        [[ "$REPLY_CHOICE" == "__EXIT__" ]] && { echo "Exiting."; exit 0; }
        local chosen_arch="$REPLY_CHOICE"

        # ---- Level 3: version (maps to a root product id) ----
        local -a vlabels=() vids=()
        while IFS=$'\t' read -r vid vver; do
            [[ -z "$vid" ]] && continue
            vids+=("$vid"); vlabels+=("$vver")
        done < <(menu_versions_for_name_arch "$chosen_name" "$chosen_arch")
        hr; info "Version for: ${C_BOLD}${chosen_name} ${chosen_arch}${C_RESET}"; hr
        choose "Available versions:" "${vlabels[@]}"
        [[ "$REPLY_CHOICE" == "__EXIT__" ]] && { echo "Exiting."; exit 0; }
        # find the id for the chosen version label
        local root="" i
        for i in "${!vlabels[@]}"; do
            [[ "${vlabels[$i]}" == "$REPLY_CHOICE" ]] && { root="${vids[$i]}"; break; }
        done
        [[ -n "$root" ]] || { warn "Could not resolve version."; continue; }

        # ---- Level 4: tree walk ----
        load_tree_for_root "$root"
        if walk_tree "$root"; then
            finalize_selection "$root"
        else
            warn "Cancelled this base; nothing enabled."
        fi

        echo
        read -rp "Select another prod

                                     uct? [y/N] " again
        [[ "${again:-N}" =~ ^[Yy]$ ]] || { echo "Done."; exit 0; }
    done
}

main "$@"
