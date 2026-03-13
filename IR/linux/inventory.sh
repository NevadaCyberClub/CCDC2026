#!/usr/bin/env bash
# server_summary.sh — Compact server audit script

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ─── Helpers ───────────────────────────────────────────────────────────────────
sep()      { printf "${DIM}%110s${RESET}\n" | tr ' ' '─'; }
header()   { echo; echo -e "  ${BOLD}${CYAN}$1${RESET}"; sep; }
get_users(){ grep "^$1:" /etc/group 2>/dev/null | cut -d: -f4 | tr ',' '\n'; }
cmd()      { command -v "$1" >/dev/null 2>&1; }
stringContain() { case $2 in *$1*) return 0;; *) return 1;; esac; }

# Systemd status: colored symbol
svc_status() {
    if cmd systemctl; then
        case "$(systemctl is-active "$1" 2>/dev/null)" in
            active)   echo -e "${GREEN}●${RESET}"; return ;;
            inactive) echo -e "${DIM}○${RESET}";   return ;;
            failed)   echo -e "${RED}✗${RESET}";   return ;;
        esac
    fi
    if cmd rc-service; then
        case "$(rc-service "$1" status 2>/dev/null)" in
            *started*)  echo -e "${GREEN}●${RESET}"; return ;;
            *stopped*)  echo -e "${DIM}○${RESET}";   return ;;
            *crashed*)  echo -e "${RED}✗${RESET}";   return ;;
        esac
    fi
    if pgrep -x "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}●${RESET}"
    else
        echo -e "${YELLOW}?${RESET}"
    fi
}

# Version from binary --version
get_ver() {
    cmd "$1" && "$1" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Single compact service row:  ● Label         v2.4.57   /etc/cfg
svc_row() {
    local label="$1" unit="$2" bin="$3" cfg="$4"
    local status ver
    status=$(svc_status "$unit")
    ver=$(get_ver "$bin"); [ -n "$ver" ] && ver="v${ver}" || ver="${DIM}—${RESET}"
    printf "  %b %-22s %-14b %b\n" \
        "$status" "$label" "${DIM}${ver}${RESET}" "${DIM}${cfg}${RESET}"
}

# ─── System info ───────────────────────────────────────────────────────────────
HOSTNAME=$(hostname 2>/dev/null || cat /etc/hostname)
IP_ADDR=$(ip a 2>/dev/null \
    | grep -oE '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}/[[:digit:]]{1,2}' \
    | grep -v '127.0.0.1' \
    || ifconfig 2>/dev/null | grep -oE 'inet [^ ]+' | grep -v '127.0.0.1' | awk '{print $2}')
OS=$(hostnamectl 2>/dev/null | grep "Operating System" | cut -d: -f2 \
    || grep PRETTY_NAME /etc/*-release 2>/dev/null | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
LOAD=$(uptime | grep -oE 'load average[s]?:.*')

echo
sep
printf "  ${BOLD}${CYAN}SERVER: %s${RESET}\n" "$HOSTNAME"
sep
printf "  %-14s %s\n" "IP:"     "$IP_ADDR"
printf "  %-14s %s\n" "OS:"     "$OS"
printf "  %-14s %s\n" "Kernel:" "$KERNEL"
printf "  %-14s %s\n" "Load:"   "$LOAD"
printf "  %-14s %s\n" "User:"   "$USER"
printf "  %-14s %s\n" "Date:"   "$(date)"

# ═══════════════════════════════════════════════════════════════════════════════
#  SERVICES
# ═══════════════════════════════════════════════════════════════════════════════
header "SERVICES"
printf "  ${BOLD}  %-22s %-14s %s${RESET}\n" "Service" "Version" "Config"
sep

# ── Web ────────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}Web${RESET}"
if [ -e "/etc/apache2/apache2.conf" ] || [ -e "/etc/httpd/httpd.conf" ]; then
    cfg=$(ls /etc/apache2/apache2.conf /etc/httpd/httpd.conf 2>/dev/null | head -1)
    svc_row "Apache2" "apache2" "apache2" "$cfg"
fi
[ -e "/etc/nginx/nginx.conf" ] && \
    svc_row "Nginx" "nginx" "nginx" "/etc/nginx/nginx.conf"

# ── SSH ────────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}SSH${RESET}"
[ -e "/etc/ssh/sshd_config" ] && \
    svc_row "OpenSSH" "sshd" "sshd" "/etc/ssh/sshd_config"
{ [ -e "/etc/dropbear/dropbear_config" ] || [ -e "/etc/default/dropbear" ]; } && \
    svc_row "Dropbear" "dropbear" "dropbear" \
        "$(ls /etc/dropbear/dropbear_config /etc/default/dropbear 2>/dev/null | head -1)"

# ── Mail ───────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}Mail${RESET}"
[ -e "/etc/postfix/main.cf" ]      && svc_row "Postfix"  "postfix"  "postfix"  "/etc/postfix/main.cf"
[ -e "/etc/dovecot/dovecot.conf" ] && svc_row "Dovecot"  "dovecot"  "dovecot"  "/etc/dovecot/dovecot.conf"
[ -e "/etc/mail/sendmail.cf" ]     && svc_row "Sendmail" "sendmail" "sendmail" "/etc/mail/sendmail.cf"
[ -e "/etc/exim4/exim4.conf" ]     && svc_row "Exim"     "exim4"    "exim4"    "/etc/exim4/exim4.conf"

# ── FTP ────────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}FTP${RESET}"
{ [ -e "/etc/vsftpd.conf" ] || [ -e "/etc/vsftpd/vsftpd.conf" ]; } && \
    svc_row "vsftpd" "vsftpd" "vsftpd" \
        "$(ls /etc/vsftpd.conf /etc/vsftpd/vsftpd.conf 2>/dev/null | head -1)"
{ [ -e "/etc/proftpd.conf" ] || [ -e "/etc/proftpd/proftpd.conf" ]; } && \
    svc_row "ProFTPD" "proftpd" "proftpd" \
        "$(ls /etc/proftpd.conf /etc/proftpd/proftpd.conf 2>/dev/null | head -1)"
{ [ -e "/etc/pure-ftpd.conf" ] || [ -e "/etc/pure-ftpd/pure-ftpd.conf" ]; } && \
    svc_row "Pure-FTPd" "pure-ftpd" "" \
        "$(ls /etc/pure-ftpd.conf /etc/pure-ftpd/pure-ftpd.conf 2>/dev/null | head -1)"

# ── Databases ──────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}Databases${RESET}"
if [ -e "/etc/mysql/my.cnf" ] || [ -e "/etc/my.cnf" ] || [ -e "/etc/mysql/mysql.conf.d/mysqld.cnf" ]; then
    cfg=$(ls /etc/mysql/my.cnf /etc/my.cnf /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null | head -1)
    svc_row "MySQL/MariaDB" "mysql" "mysql" "$cfg"
fi
if [ -d "/etc/postgresql" ]; then
    cfg=$(find /etc/postgresql -name "postgresql.conf" 2>/dev/null | head -1)
    svc_row "PostgreSQL" "postgresql" "psql" "$cfg"
fi
{ [ -e "/etc/mongod.conf" ] || [ -e "/etc/mongodb.conf" ]; } && \
    svc_row "MongoDB" "mongod" "mongod" \
        "$(ls /etc/mongod.conf /etc/mongodb.conf 2>/dev/null | head -1)"
[ -e "/etc/redis/redis.conf" ] && \
    svc_row "Redis" "redis" "redis-server" "/etc/redis/redis.conf"

# ── Other ──────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}Other${RESET}"
[ -e "/etc/samba/smb.conf" ]                   && svc_row "Samba"      "smbd"            "samba"   "/etc/samba/smb.conf"
[ -e "/etc/openvpn/server.conf" ]              && svc_row "OpenVPN"    "openvpn"         "openvpn" "/etc/openvpn/server.conf"
[ -e "/var/ossec/etc/ossec.conf" ]             && svc_row "Wazuh"      "wazuh-manager"   ""        "/var/ossec/etc/ossec.conf"
[ -e "/opt/splunk/etc/system/local/web.conf" ] && svc_row "Splunk"     "SplunkForwarder" ""        "/opt/splunk/etc/system/local/web.conf"
[ -e "/etc/cups/cupsd.conf" ]                  && svc_row "CUPS"       "cups"            ""        "/etc/cups/cupsd.conf"
[ -e "/etc/unrealircd/unrealircd.conf" ]       && svc_row "UnrealIRCd" "unrealircd"      ""        "/etc/unrealircd/unrealircd.conf"
[ -e "/etc/inspircd/inspircd.conf" ]           && svc_row "InspIRCd"   "inspircd"        ""        "/etc/inspircd/inspircd.conf"

# ── PHP (compact list) ─────────────────────────────────────────────────────────
echo -e "  ${YELLOW}PHP${RESET}"
php_found=0
for f in \
    /etc/php5/{apache2,cli,fpm}/php.ini \
    /etc/php/{7.0,7.1,7.2,7.3,7.4,8.0,8.1,8.2,8.3}/{apache2,cli,fpm}/php.ini \
    /etc/php.ini; do
    [ -e "$f" ] || continue
    ver=$(echo "$f" | grep -oE '[0-9]+\.[0-9]+' || echo "?")
    sapi=$(echo "$f" | grep -oE 'apache2|cli|fpm' || echo "unknown")
    printf "  ${DIM}  ○ php%-4s (%-7s)  %s${RESET}\n" "$ver" "$sapi" "$f"
    php_found=1
done
[ "$php_found" -eq 0 ] && echo -e "  ${DIM}  No PHP found${RESET}"

# ═══════════════════════════════════════════════════════════════════════════════
#  OPEN PORTS
# ═══════════════════════════════════════════════════════════════════════════════
header "OPEN PORTS"
if cmd ss; then
    ss -tulpn 2>/dev/null \
    | awk 'NR==1{printf "  \033[1m%-6s %-6s %-32s %-32s %s\033[0m\n",$1,$2,$4,$5,$7; next}
               {printf "  %-6s %-6s %-32s %-32s %s\n",$1,$2,$4,$5,$7}' \
    | sort -V -k4
elif cmd netstat; then
    netstat -tulpn 2>/dev/null | grep LISTEN | sed 's/^/  /'
elif cmd lsof; then
    lsof -i -P -n 2>/dev/null | grep LISTEN | sed 's/^/  /'
else
    echo -e "  ${RED}No suitable tool found (ss/netstat/lsof)${RESET}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  CONTAINERS
# ═══════════════════════════════════════════════════════════════════════════════
header "CONTAINERS"
if ! cmd docker; then
    echo -e "  ${DIM}Docker not installed${RESET}"
else
    echo -e "  ${BOLD}Running${RESET}"
    running=$(docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" 2>/dev/null)
    if [ -z "$running" ]; then
        echo -e "  ${DIM}  None${RESET}"
    else
        printf "  ${BOLD}%-30s %-22s %-25s %-25s${RESET}\n" "Name" "Image" "Internal" "External"
        echo "$running" | while IFS=$'\t' read -r name status ports image; do
            stringContain "(Paused)" "$status" && continue
            int=$(echo "$ports" | awk -F'->' '{print $1}' | tr ',' '\n' | awk -F'/' '{print $1}' | tr '\n' ',' | sed 's/,$//')
            ext=$(echo "$ports" | awk -F'->' '{print $2}' | awk -F',' '{print $1}' | tr '\n' ',' | sed 's/,$//')
            [ -z "$int" ] && int="N/A"; [ -z "$ext" ] && ext="N/A"
            printf "  ${GREEN}●${RESET} %-29s %-22s %-25s %-25s\n" "$name" "${image%%:*}" "$int" "$ext"
        done
    fi

    echo -e "  ${BOLD}Stopped${RESET}"
    stopped=$(docker ps -a \
        --filter "status=exited" --filter "status=paused" \
        --filter "status=dead"   --filter "status=restarting" \
        --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)
    if [ -z "$stopped" ]; then
        echo -e "  ${DIM}  None${RESET}"
    else
        printf "  ${BOLD}%-30s %-22s %-30s${RESET}\n" "Name" "Image" "Status"
        echo "$stopped" | while IFS=$'\t' read -r name status image; do
            color="${YELLOW}"
            echo "$status" | grep -qi "exited (0)" && color="${DIM}"
            echo "$status" | grep -qi "dead"        && color="${RED}"
            printf "  ${color}○${RESET} %-29s %-22s %-30s\n" "$name" "${image%%:*}" "$status"
        done
    fi
fi

if cmd kubectl; then
    echo -e "  ${BOLD}Kubernetes${RESET}"
    k=$(kubectl get nodes "$HOSTNAME" 2>/dev/null | grep "control-plane")
    if [ -z "$k" ]; then
        echo -e "  ${YELLOW}  Worker node${RESET}"
    else
        echo -e "  ${CYAN}  Control plane${RESET}"
        kubectl get nodes -o wide 2>/dev/null | sed 's/^/  /'
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  USERS & ACCESS
# ═══════════════════════════════════════════════════════════════════════════════
header "USERS & ACCESS"
echo -e "  ${BOLD}Human users${RESET}"
awk -F: '($3 >= 1000 || $1 == "root") && $1 != "nobody" {
    printf "  %-18s UID:%-6s %-25s %s\n", $1, $3, $6, $7
}' /etc/passwd

echo -e "\n  ${BOLD}Sudo / Wheel${RESET}"
combined=$(printf "%s\n%s" "$(get_users sudo)" "$(get_users wheel)" | sort -u | grep -v '^$')
if [ -z "$combined" ]; then
    echo -e "  ${DIM}  None${RESET}"
else
    echo "$combined" | while read -r u; do printf "  ${RED}⚠${RESET}  %s\n" "$u"; done
fi

echo
if [ -e "/etc/krb5.conf" ]; then
    domain=$(awk '/default_realm/{print $3}' /etc/krb5.conf)
    echo -e "  ${CYAN}Domain joined: $domain${RESET}"
else
    echo -e "  ${DIM}Not domain joined${RESET}"
fi

# ── Transactional update (openSUSE MicroOS) ────────────────────────────────────
if cmd transactional-update; then
    header "TRANSACTIONAL UPDATE"
    transactional-update status 2>/dev/null | sed 's/^/  /'
fi

sep
echo -e "  ${DIM}$(date)${RESET}"
sep
echo