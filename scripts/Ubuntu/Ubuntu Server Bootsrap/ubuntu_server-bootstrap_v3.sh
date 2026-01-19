#!/bin/bash

################################################################################
# Server Bootstrap Script - Enterprise Homelab Initial Configuration
#
# Purpose: Configure new Ubuntu servers with static IP, hostname, timezone, and ansible user
# Author:  Noble's Homelab Automation
# Version: 2.3.2  (Restored netplan mapping + clear dry-run)
################################################################################

set -euo pipefail

SCRIPT_VERSION="2.3.2"
LOG_FILE="/var/log/server-bootstrap.log"
BACKUP_DIR="/var/backups/server-bootstrap"
NETPLAN_CONFIG=""
HOSTS_FILE="/etc/hosts"
ANSIBLE_USER="ansible"
DEFAULT_TIMEZONE="America/Chicago"
MIN_DISK_SPACE_MB=100
CONTROLLER_SSH_PUBKEY_HINT="~/.ssh/ansible-automation-key.pub"

DRY_RUN=false
INTERACTIVE=true
NEW_HOSTNAME=""
STATIC_IP=""
GATEWAY_IP=""
DNS_SERVER=""
SUBNET_MASK="24"
TIMEZONE="$DEFAULT_TIMEZONE"
CREATE_ANSIBLE_USER=false

DETECTED_INTERFACE=""
DETECTED_GATEWAY=""
CURRENT_IP=""
MAC_ADDRESS=""

# Colors
if [[ -t 1 ]] && command -v tput &> /dev/null; then
    RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4); CYAN=$(tput setaf 6); BOLD=$(tput bold); RESET=$(tput sgr0)
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; RESET=""
fi

init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    log "INFO" "=========================================="
    log "INFO" "Server Bootstrap Script v${SCRIPT_VERSION}"
    log "INFO" "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "User: $(whoami)"
    log "INFO" "=========================================="
}

log() {
    local level="$1"; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

print_info(){ echo -e "${BLUE}ℹ${RESET} $*"; log "INFO" "$*"; }
print_success(){ echo -e "${GREEN}✓${RESET} $*"; log "SUCCESS" "$*"; }
print_warning(){ echo -e "${YELLOW}⚠${RESET} $*"; log "WARNING" "$*"; }
print_error(){ echo -e "${RED}✗${RESET} $*" >&2; log "ERROR" "$*"; }
print_header(){
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_disk_space() {
    local available_mb
    available_mb=$(df -m /var | tail -1 | awk '{print $4}')
    if (( available_mb < MIN_DISK_SPACE_MB )); then
        print_error "Insufficient disk space in /var: ${available_mb}MB available"
        exit 1
    fi
}

check_netplan() {
    if ! command -v netplan &> /dev/null; then
        print_error "Netplan is not installed on this system"
        exit 1
    fi
    print_success "Netplan available: $(netplan --version 2>&1 | head -1 || echo 'version unknown')"
}

validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    [[ $ip =~ $ip_regex ]] || return 1
    IFS='.' read -ra OCTETS <<< "$ip"
    for o in "${OCTETS[@]}"; do
        (( o >= 0 && o <= 255 )) || return 1
    done
    return 0
}

validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
    [[ $hostname =~ $hostname_regex ]] || return 1
    [[ ${#hostname} -le 63 ]] || return 1
    local reserved=("localhost" "localdomain" "broadcasthost" "ip6-localhost" "ip6-loopback")
    for r in "${reserved[@]}"; do
        [[ "$hostname" == "$r" ]] && return 1
    done
    return 0
}

validate_subnet_mask() {
    local mask="$1"
    [[ $mask =~ ^[0-9]+$ ]] || return 1
    (( mask >= 1 && mask <= 32 )) || return 1
    return 0
}

check_ansible_user() { id "$ANSIBLE_USER" &>/dev/null; }

init_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    print_success "Backup directory initialized: $BACKUP_DIR"
}

backup_file() {
    local file="$1"
    local timestamp backup_path
    timestamp=$(date '+%Y%m%d_%H%M%S')
    backup_path="${BACKUP_DIR}/$(basename "$file").${timestamp}"
    if [[ -f "$file" ]]; then
        cp -a "$file" "$backup_path"
        print_success "Backed up: $(basename "$file") → $(basename "$backup_path")"
        echo "$backup_path"
    fi
}

restore_backup() {
    local file="$1"
    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}/$(basename "$file")."* 2>/dev/null | head -n1 || true)
    if [[ -n "$latest_backup" ]]; then
        cp -a "$latest_backup" "$file"
        print_success "Restored $(basename "$file") from backup"
    else
        print_error "No backup found for $file"
        return 1
    fi
}

detect_network_interface() {
    print_info "Detecting active network interface..."

    local interfaces=()
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | grep -v '^docker' | grep -v '^br-' | grep -v '^veth')

    local active_interfaces=()
    for iface in "${interfaces[@]}"; do
        if ip addr show "$iface" 2>/dev/null | grep -q "state UP" && ip addr show "$iface" 2>/dev/null | grep -q "inet "; then
            active_interfaces+=("$iface")
        fi
    done

    if [[ ${#active_interfaces[@]} -eq 0 ]]; then
        print_error "No active interfaces found"
        exit 1
    elif [[ ${#active_interfaces[@]} -eq 1 ]]; then
        DETECTED_INTERFACE="${active_interfaces[0]}"
        print_success "Detected active interface: $DETECTED_INTERFACE"
    else
        print_warning "Multiple active interfaces detected:"
        for i in "${!active_interfaces[@]}"; do
            local ipaddr
            ipaddr=$(ip -4 addr show "${active_interfaces[$i]}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || true)
            echo "  $((i+1))) ${active_interfaces[$i]}  ($ipaddr)"
        done
        echo ""
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Select interface number: " idx
            DETECTED_INTERFACE="${active_interfaces[$((idx-1))]}"
        else
            DETECTED_INTERFACE="${active_interfaces[0]}"
        fi
    fi

    CURRENT_IP=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || true)
    MAC_ADDRESS=$(ip link show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=link/ether\s)[0-9a-f:]+' | head -1 || true)

    print_info "Current IP: $CURRENT_IP"
    print_info "MAC Address: $MAC_ADDRESS"
    log "INFO" "Selected interface: $DETECTED_INTERFACE ($CURRENT_IP)"
}

detect_gateway() {
    DETECTED_GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1 || true)
    [[ -n "$DETECTED_GATEWAY" ]] && print_info "Detected gateway: $DETECTED_GATEWAY" || print_warning "Could not detect gateway"
}

# ---------- RESTORED: netplan file “who manages what” summary ----------

# Extract interface names defined in a netplan file (best-effort)
netplan_list_ifaces_in_file() {
    local file="$1"
    # Look for lines like "eth0:" "eth1:" "ens160:" under ethernets:
    awk '
      $1 ~ /^ethernets:$/ {in_eth=1; next}
      in_eth && $1 ~ /^[a-zA-Z0-9._-]+:$/ {gsub(":","",$1); print $1}
      in_eth && $1 ~ /^[a-zA-Z]+:$/ && $1!="ethernets:" && $1!="wifis:" && $1!="bridges:" && $1!="bonds:" { }
      $1 ~ /^wifis:$/ {in_eth=0}
      $1 ~ /^bridges:$/ {in_eth=0}
      $1 ~ /^bonds:$/ {in_eth=0}
    ' "$file" 2>/dev/null | sed '/^$/d' | sort -u
}

netplan_file_dhcp_status() {
    local file="$1"
    if grep -q "dhcp4:\s*true" "$file" 2>/dev/null; then
        echo "DHCP"
    elif grep -q "dhcp4:\s*false" "$file" 2>/dev/null; then
        echo "Static"
    else
        echo "Unknown"
    fi
}

netplan_file_matches_mac() {
    local file="$1"
    local mac_lower
    mac_lower=$(echo "$MAC_ADDRESS" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$mac_lower" ]] && grep -qi "macaddress:\s*$mac_lower" "$file" 2>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

detect_netplan_config() {
    print_info "Detecting netplan configuration file..."

    local netplan_files=()
    while IFS= read -r -d '' file; do
        [[ "$file" =~ \.backup$ ]] && continue
        [[ "$file" =~ ~$ ]] && continue
        netplan_files+=("$file")
    done < <(find /etc/netplan -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) -type f -print0 2>/dev/null)

    if [[ ${#netplan_files[@]} -eq 0 ]]; then
        print_warning "No netplan files found; will create /etc/netplan/00-installer-config.yaml"
        NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml"
        return 0
    fi

    if [[ ${#netplan_files[@]} -eq 1 ]]; then
        NETPLAN_CONFIG="${netplan_files[0]}"
        print_success "Found netplan config: $(basename "$NETPLAN_CONFIG")"
        return 0
    fi

    print_warning "Multiple netplan configuration files detected:"
    echo ""
    for i in "${!netplan_files[@]}"; do
        local f="${netplan_files[$i]}"
        local bn size mtime ifaces dhcp macmatch
        bn=$(basename "$f")
        size=$(stat -c%s "$f" 2>/dev/null || echo "?")
        mtime=$(stat -c%y "$f" 2>/dev/null | cut -d'.' -f1 || echo "?")
        ifaces=$(netplan_list_ifaces_in_file "$f" | tr '\n' ',' | sed 's/,$//')
        [[ -z "$ifaces" ]] && ifaces="(none found)"
        dhcp=$(netplan_file_dhcp_status "$f")
        macmatch=$(netplan_file_matches_mac "$f")

        echo "  $((i+1))) $bn (${size} bytes)"
        echo "      ├─ Modified: $mtime"
        echo "      ├─ Interfaces: $ifaces"
        echo "      ├─ Mode: $dhcp"
        echo "      └─ MAC match (${MAC_ADDRESS:-unknown}): $macmatch"
        echo ""
    done

    # Helpful hint: suggest file that mentions the selected interface
    local suggested=""
    for f in "${netplan_files[@]}"; do
        if grep -qE "^\s*${DETECTED_INTERFACE}\s*:" "$f" 2>/dev/null; then
            suggested="$f"
            break
        fi
    done

    if [[ -n "$suggested" ]]; then
        print_info "Suggested file (contains '${DETECTED_INTERFACE}:'): $(basename "$suggested")"
    else
        print_warning "No file explicitly contains '${DETECTED_INTERFACE}:' — pick the one that looks active (DHCP/Static) for your VM type."
    fi
    echo ""

    if [[ "$INTERACTIVE" == true ]]; then
        read -p "Select the netplan file number to use: " choice
        NETPLAN_CONFIG="${netplan_files[$((choice-1))]}"
    else
        NETPLAN_CONFIG="${netplan_files[0]}"
        print_warning "Non-interactive: using first file: $(basename "$NETPLAN_CONFIG")"
    fi

    print_success "Selected: $(basename "$NETPLAN_CONFIG")"
    log "INFO" "Using netplan config: $NETPLAN_CONFIG"
}

prompt_hostname() {
    local current
    current=$(hostname)
    echo ""
    print_info "Current hostname: ${BOLD}$current${RESET}"
    read -p "Enter new hostname [Enter keeps '$current']: " input
    if [[ -z "$input" ]]; then
        NEW_HOSTNAME="$current"
        return
    fi
    if validate_hostname "$input"; then
        NEW_HOSTNAME="$input"
    else
        print_error "Invalid hostname. Using current."
        NEW_HOSTNAME="$current"
    fi
}

prompt_static_ip() {
    echo ""
    print_info "Current IP: ${BOLD}$CURRENT_IP${RESET}"
    read -p "Configure static IP? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { STATIC_IP=""; return; }

    while true; do
        read -p "Static IP [$CURRENT_IP]: " ip
        ip="${ip:-$CURRENT_IP}"
        validate_ip "$ip" && { STATIC_IP="$ip"; break; } || print_error "Invalid IP"
    done
    while true; do
        read -p "Subnet mask [24]: " m
        m="${m:-24}"
        validate_subnet_mask "$m" && { SUBNET_MASK="$m"; break; } || print_error "Invalid mask"
    done
    local gw_default="${DETECTED_GATEWAY:-}"
    while true; do
        read -p "Gateway [${gw_default}]: " gw
        gw="${gw:-$gw_default}"
        validate_ip "$gw" && { GATEWAY_IP="$gw"; break; } || print_error "Invalid gateway"
    done
    while true; do
        read -p "DNS server [$GATEWAY_IP]: " dns
        dns="${dns:-$GATEWAY_IP}"
        validate_ip "$dns" && { DNS_SERVER="$dns"; break; } || print_error "Invalid DNS"
    done
}

prompt_timezone() {
    echo ""
    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    print_info "Current timezone: ${BOLD}$current_tz${RESET}"
    read -p "Timezone [$DEFAULT_TIMEZONE]: " tz
    TIMEZONE="${tz:-$DEFAULT_TIMEZONE}"
}

prompt_ansible_user() {
    echo ""
    if check_ansible_user; then
        print_info "User '$ANSIBLE_USER' exists."
        read -p "Reconfigure ansible user anyway? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && CREATE_ANSIBLE_USER=true || CREATE_ANSIBLE_USER=false
    else
        read -p "Create ansible service account? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && CREATE_ANSIBLE_USER=true || CREATE_ANSIBLE_USER=false
    fi
}

display_config_summary() {
    print_header "Configuration Summary"
    echo -e "${BOLD}Hostname:${RESET} $NEW_HOSTNAME"
    echo -e "${BOLD}Interface:${RESET} $DETECTED_INTERFACE ($CURRENT_IP)"
    echo -e "${BOLD}Netplan file:${RESET} $(basename "$NETPLAN_CONFIG")"
    if [[ -n "$STATIC_IP" ]]; then
        echo -e "${BOLD}Static IP:${RESET} $STATIC_IP/$SUBNET_MASK  GW:$GATEWAY_IP  DNS:$DNS_SERVER"
    else
        echo -e "${BOLD}Network:${RESET} No change"
    fi
    echo -e "${BOLD}Timezone:${RESET} $TIMEZONE"
    echo -e "${BOLD}Ansible user:${RESET} $ANSIBLE_USER  (create/reconfigure: $CREATE_ANSIBLE_USER)"
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: no changes will be applied."
        return 0
    fi
    read -p "Apply this configuration? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
}

configure_hostname() {
    [[ "$(hostname)" == "$NEW_HOSTNAME" ]] && { print_info "Hostname already: $NEW_HOSTNAME"; return 0; }
    print_info "Setting hostname: $NEW_HOSTNAME"
    [[ "$DRY_RUN" == true ]] && { print_info "[DRY RUN] hostnamectl set-hostname $NEW_HOSTNAME"; return 0; }
    backup_file "$HOSTS_FILE" >/dev/null || true
    hostnamectl set-hostname "$NEW_HOSTNAME"
    if grep -q "^127.0.1.1" "$HOSTS_FILE"; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" "$HOSTS_FILE"
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> "$HOSTS_FILE"
    fi
    print_success "Hostname configured"
}

configure_timezone() {
    print_info "Setting timezone: $TIMEZONE"
    [[ "$DRY_RUN" == true ]] && { print_info "[DRY RUN] timedatectl set-timezone $TIMEZONE"; return 0; }
    timedatectl set-timezone "$TIMEZONE" || true
    print_success "Timezone configured"
}

configure_ansible_user() {
    [[ "$CREATE_ANSIBLE_USER" != true ]] && { print_info "Skipping ansible user config"; return 0; }
    print_info "Configuring ansible user: $ANSIBLE_USER"
    [[ "$DRY_RUN" == true ]] && { print_info "[DRY RUN] would create user + sudoers + ssh dir"; return 0; }

    if ! check_ansible_user; then
        useradd -m -s /bin/bash "$ANSIBLE_USER"
        passwd -l "$ANSIBLE_USER" >/dev/null 2>&1 || true
    fi

    usermod -aG sudo "$ANSIBLE_USER" >/dev/null 2>&1 || true
    echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ANSIBLE_USER"
    chmod 0440 "/etc/sudoers.d/$ANSIBLE_USER"
    visudo -c -f "/etc/sudoers.d/$ANSIBLE_USER" >/dev/null

    local home="/home/$ANSIBLE_USER"
    mkdir -p "$home/.ssh"
    touch "$home/.ssh/authorized_keys"
    chmod 700 "$home/.ssh"
    chmod 600 "$home/.ssh/authorized_keys"
    chown -R "$ANSIBLE_USER:$ANSIBLE_USER" "$home/.ssh"

    print_success "Ansible user configured"
}

configure_static_ip_last() {
    [[ -z "$STATIC_IP" ]] && { print_info "Network unchanged"; return 0; }

    print_info "Writing netplan static config to: $NETPLAN_CONFIG"
    [[ "$DRY_RUN" == true ]] && { print_info "[DRY RUN] would write netplan + (optional) apply"; return 0; }

    backup_file "$NETPLAN_CONFIG" >/dev/null || true

    local mac_match=""
    if [[ -n "$MAC_ADDRESS" ]]; then
        mac_match="      match:
        macaddress: $MAC_ADDRESS
      set-name: $DETECTED_INTERFACE"
    fi

    cat > "$NETPLAN_CONFIG" <<EOF
# Generated by server-bootstrap.sh v${SCRIPT_VERSION} - $(date '+%Y-%m-%d %H:%M:%S')
network:
  version: 2
  ethernets:
    $DETECTED_INTERFACE:
$mac_match
      dhcp4: false
      dhcp6: false
      addresses:
        - $STATIC_IP/$SUBNET_MASK
      routes:
        - to: default
          via: $GATEWAY_IP
      nameservers:
        addresses:
          - $DNS_SERVER
          - 8.8.8.8
EOF

    chmod 600 "$NETPLAN_CONFIG"

    netplan generate

    echo ""
    print_warning "Network change is the LAST step. Applying may disconnect SSH."
    print_info "After apply, reconnect to: ssh <user>@$STATIC_IP"
    echo ""
    read -p "Apply netplan now? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || {
        print_warning "Skipped netplan apply. File written."
        print_info "Apply later from console: sudo netplan apply"
        return 0
    }

    print_warning "Applying netplan..."
    timeout 30 netplan apply
    print_success "Netplan applied"
}

show_help() {
    cat <<EOF
Server Bootstrap Script v${SCRIPT_VERSION}

USAGE:
  Interactive:
    sudo $0

  Dry-run (shows what would happen; no changes):
    sudo $0 --dry-run

  Non-interactive:
    sudo $0 --hostname NAME --ip IP --gateway GW [--dns DNS] [--subnet 24] [--timezone TZ]

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --hostname)
                NEW_HOSTNAME="$2"; INTERACTIVE=false; shift 2 ;;
            --ip)
                STATIC_IP="$2"; INTERACTIVE=false; shift 2 ;;
            --gateway)
                GATEWAY_IP="$2"; shift 2 ;;
            --dns)
                DNS_SERVER="$2"; shift 2 ;;
            --subnet|--mask)
                SUBNET_MASK="$2"; shift 2 ;;
            --timezone)
                TIMEZONE="$2"; shift 2 ;;
            --help|-h)
                show_help; exit 0 ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1 ;;
        esac
    done
}

main() {
    print_header "Server Bootstrap Script v${SCRIPT_VERSION}"

    parse_arguments "$@"
    check_root
    init_logging
    check_disk_space
    check_netplan
    init_backup_dir

    detect_network_interface
    detect_netplan_config
    detect_gateway

    if [[ "$INTERACTIVE" == true ]]; then
        # Make DRY RUN obvious in interactive mode too
        echo ""
        read -p "Enable DRY RUN (no changes will be made)? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && DRY_RUN=true

        prompt_hostname
        prompt_static_ip
        prompt_timezone
        prompt_ansible_user
    else
        [[ -z "$NEW_HOSTNAME" ]] && NEW_HOSTNAME="$(hostname)"

        if [[ -n "$STATIC_IP" ]]; then
            validate_ip "$STATIC_IP" || { print_error "Invalid --ip"; exit 1; }
            [[ -n "$GATEWAY_IP" ]] || { print_error "--gateway required with --ip"; exit 1; }
            validate_ip "$GATEWAY_IP" || { print_error "Invalid --gateway"; exit 1; }
            [[ -z "$DNS_SERVER" ]] && DNS_SERVER="$GATEWAY_IP"
            validate_subnet_mask "$SUBNET_MASK" || { print_error "Invalid --subnet"; exit 1; }
        fi

        CREATE_ANSIBLE_USER=true
    fi

    display_config_summary

    print_header "Applying Configuration"
    configure_hostname
    configure_timezone
    configure_ansible_user
    configure_static_ip_last  # LAST step

    print_header "Complete"
    print_success "Done."
    echo ""
    echo "Next steps (from controller):"
    echo "  ssh-copy-id -i ${CONTROLLER_SSH_PUBKEY_HINT} ${ANSIBLE_USER}@${STATIC_IP:-$CURRENT_IP}"
}

main "$@"
