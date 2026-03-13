#!/usr/bin/env bash

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ─── Helpers ───────────────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}[*]${RESET} $*"; }
found() { echo -e "${YELLOW}[+]${RESET} $*"; }
hit()   { echo -e "${RED}[!]${RESET} $*"; }

# Track scanned paths to avoid duplicates
declare -A SCANNED

# ─── Pattern functions ─────────────────────────────────────────────────────────
grep_for_phone_numbers() {
    local results
    results=$(grep -REo '(\([0-9]{3}\) |[0-9]{3}-)[0-9]{3}-[0-9]{4}' "$1" 2>/dev/null)
    [ -n "$results" ] && echo "$results" | while IFS=: read -r file match; do
        hit "PHONE       $match  →  $file"
    done
}

grep_for_email_addresses() {
    local results
    results=$(grep -REo '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}' "$1" 2>/dev/null)
    [ -n "$results" ] && echo "$results" | while IFS=: read -r file match; do
        hit "EMAIL       $match  →  $file"
    done
}

grep_for_social_security_numbers() {
    # Exclude phone-number-like matches by requiring the 2nd group is exactly 2 digits
    local results
    results=$(grep -REo '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b' "$1" 2>/dev/null \
        | grep -v '[0-9]{3}-[0-9]{3}-[0-9]{4}')
    [ -n "$results" ] && echo "$results" | while IFS=: read -r file match; do
        hit "SSN         $match  →  $file"
    done
}

grep_for_credit_card_numbers() {
    # Needs -P for PCRE; falls back gracefully if unavailable
    local results
    results=$(grep -RPo '\b(?:\d{4}[-\s]?){3}\d{4}\b' "$1" 2>/dev/null)
    [ -n "$results" ] && echo "$results" | while IFS=: read -r file match; do
        hit "CREDIT CARD $match  →  $file"
    done
}

grep_for_vehicle_registration_numbers() {
    local results
    results=$(grep -REo '\b[A-Z]{1,2}[0-9]{1,2}\s?[A-Z]{1,3}\s?[0-9]{1,4}\b' "$1" 2>/dev/null)
    [ -n "$results" ] && echo "$results" | while IFS=: read -r file match; do
        hit "VEHICLE REG $match  →  $file"
    done
}

find_interesting_files() {
    find "$1" -type f \( \
        -name '*.doc'  -o -name '*.docx' -o -name '*.docm' -o -name '*.dot'  \
        -o -name '*.dotx' -o -name '*.dotm' -o -name '*.wbk'  \
        -o -name '*.xls'  -o -name '*.xlsx' -o -name '*.xlsm' -o -name '*.xlt'  \
        -o -name '*.xltx' -o -name '*.xltm' -o -name '*.xlam' -o -name '*.xlsb' \
        -o -name '*.xla'  -o -name '*.xll'  \
        -o -name '*.ppt'  -o -name '*.pptx' -o -name '*.pptm' -o -name '*.pot'  \
        -o -name '*.potx' -o -name '*.potm' -o -name '*.pps'  -o -name '*.ppsx' \
        -o -name '*.ppsm' -o -name '*.ppam' \
        -o -name '*.pdf'  -o -name '*.txt'  -o -name '*.rtf'  -o -name '*.csv'  \
        -o -name '*.odt'  -o -name '*.ods'  -o -name '*.odp'  -o -name '*.odg'  \
        -o -name '*.odf'  -o -name '*.odc'  -o -name '*.odb'  -o -name '*.odm'  \
    \) 2>/dev/null | while read -r f; do
        hit "FILE        $f"
    done
}

# ─── Main search ───────────────────────────────────────────────────────────────
search() {
    local path="$1"
    local label="${2:-$1}"

    # Resolve to absolute path and skip if already scanned
    local abs_path
    abs_path=$(realpath "$path" 2>/dev/null) || abs_path="$path"
    if [ -n "${SCANNED[$abs_path]}" ]; then
        info "Skipping $abs_path (already scanned)"
        return
    fi
    SCANNED[$abs_path]=1

    if [ ! -d "$abs_path" ] && [ ! -f "$abs_path" ]; then
        info "Path not found, skipping: $abs_path"
        return
    fi

    info "Scanning ${BOLD}$label${RESET} ($abs_path)"
    grep_for_phone_numbers           "$abs_path"
    grep_for_email_addresses         "$abs_path"
    grep_for_social_security_numbers "$abs_path"
    grep_for_credit_card_numbers     "$abs_path"
    grep_for_vehicle_registration_numbers "$abs_path"
    find_interesting_files           "$abs_path"
}

# ─── Entry point ───────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}PII Scanner${RESET}"
printf "${DIM}%60s${RESET}\n" | tr ' ' '─'
echo

# Custom path
if [ -n "$1" ]; then
    search "$1" "custom path"
fi

# Standard locations
search /home    "/home"
search /var/www "/var/www"

# vsftpd
if [ -f /etc/vsftpd.conf ]; then
    info "vsftpd config found"
    anon_root=$(grep -E '^anon_root\s*=' /etc/vsftpd.conf | awk -F= '{print $2}' | tr -d ' ')
    local_root=$(grep -E '^local_root\s*=' /etc/vsftpd.conf | awk -F= '{print $2}' | tr -d ' ')
    [ -n "$anon_root" ]  && search "$anon_root"  "vsftpd anon_root"
    [ -n "$local_root" ] && search "$local_root" "vsftpd local_root"
fi

# ProFTPD
if [ -f /etc/proftpd/proftpd.conf ]; then
    info "ProFTPD config found"
    default_root=$(grep -E '^DefaultRoot' /etc/proftpd/proftpd.conf | awk '{print $2}')
    [ -n "$default_root" ] && search "$default_root" "ProFTPD DefaultRoot"
fi

# Samba
if [ -f /etc/samba/smb.conf ]; then
    info "Samba config found"
    grep -E '^\s*path\s*=' /etc/samba/smb.conf | awk -F= '{print $2}' | tr -d ' "' | while read -r share; do
        search "$share" "Samba share: $share"
    done
fi

echo
printf "${DIM}%60s${RESET}\n" | tr ' ' '─'
echo -e "${BOLD}Done.${RESET}"
echo