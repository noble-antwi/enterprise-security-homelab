#!/bin/bash

################################################################################
# Server Bootstrap Script - Enterprise Homelab Initial Configuration
#
# Purpose: Configure new Ubuntu servers with static IP, hostname, timezone, and ansible user
# Author:  Noble's Homelab Automation
# Version: 2.3.1  (Advanced safety + consistent SSH key messaging)
#
# Key upgrades in this version:
#   ✅ Network change still happens LAST, but now has a final “Apply now?” prompt
#   ✅ Option to WRITE netplan config but NOT apply it yet (safer when on SSH)
#   ✅ Next-steps SSH key path is consistent with your controller finalize script:
#        ~/.ssh/ansible-automation-key.pub
################################################################################

set -euo pipefail  # Exit on error, undefined variables, pipe failures

################################################################################
# CONFIGURATION VARIABLES
################################################################################

SCRIPT_VERSION="2.3.1"
LOG_FILE="/var/log/server-bootstrap.log"
BACKUP_DIR="/var/backups/server-bootstrap"
NETPLAN_CONFIG=""  # Will be auto-detected
HOSTS_FILE="/etc/hosts"
ANSIBLE_USER="ansible"
DEFAULT_TIMEZONE="America/Chicago"
MIN_DISK_SPACE_MB=100  # Minimum free space required

# This is only for PRINTED instructions (the key actually lives on the controller)
CONTROLLER_SSH_PUBKEY_HINT="~/.ssh/ansible-automation-key.pub"

# Command line arguments
DRY_RUN=false
INTERACTIVE=true
NEW_HOSTNAME=""
STATIC_IP=""
GATEWAY_IP=""
DNS_SERVER=""
SUBNET_MASK="24"  # Default /24
TIMEZONE="$DEFAULT_TIMEZONE"
CREATE_ANSIBLE_USER=false

# Detected values
DETECTED_INTERFACE=""
DETECTED_GATEWAY=""
CURRENT_IP=""
MAC_ADDRESS=""

################################################################################
# COLOR DEFINITIONS
################################################################################

# Check if terminal supports colors
if [[ -t 1 ]] && command -v tput &> /dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BOLD=""
    RESET=""
fi

################################################################################
# LOGGING FUNCTIONS
################################################################################

# Initialize log file
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

# Log function with timestamp and level
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Print functions with colors
print_info() {
    echo -e "${BLUE}ℹ${RESET} $*"
    log "INFO" "$*"
}

print_success() {
    echo -e "${GREEN}✓${RESET} $*"
    log "SUCCESS" "$*"
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $*"
    log "WARNING" "$*"
}

print_error() {
    echo -e "${RED}✗${RESET} $*" >&2
    log "ERROR" "$*"
}

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

# Validate IP address format
validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! $ip =~ $ip_regex ]]; then
        return 1
    fi

    # Check each octet is 0-255
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if (( octet < 0 || octet > 255 )); then
            return 1
        fi
    done

    # Check for reserved IPs
    if [[ "$ip" =~ ^0\. ]] || [[ "$ip" =~ ^127\. ]] || [[ "$ip" =~ ^255\. ]]; then
        print_warning "IP $ip appears to be a reserved address"
    fi

    return 0
}

# Validate hostname format
validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'

    # Check format
    if [[ ! $hostname =~ $hostname_regex ]]; then
        return 1
    fi

    # Check for reserved hostnames
    local reserved=("localhost" "localdomain" "broadcasthost" "ip6-localhost" "ip6-loopback")
    for reserved_name in "${reserved[@]}"; do
        if [[ "$hostname" == "$reserved_name" ]]; then
            print_error "Hostname '$hostname' is reserved and cannot be used"
            return 1
        fi
    done

    # Check length
    if [[ ${#hostname} -gt 63 ]]; then
        print_error "Hostname too long (max 63 characters)"
        return 1
    fi

    return 0
}

# Validate subnet mask
validate_subnet_mask() {
    local mask="$1"

    if [[ ! $mask =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if (( mask < 1 || mask > 32 )); then
        return 1
    fi

    return 0
}

################################################################################
# SYSTEM CHECK FUNCTIONS
################################################################################

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS version"
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        print_warning "This script is designed for Ubuntu. You're running: ${ID:-unknown} ${VERSION:-unknown}"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_warning "Non-interactive mode: proceeding with ${ID:-unknown}"
        fi
    fi

    print_info "Detected OS: ${PRETTY_NAME:-unknown}"
    log "INFO" "OS Details: ${ID:-unknown} ${VERSION_ID:-unknown} (${VERSION_CODENAME:-unknown})"
}

# Check available disk space
check_disk_space() {
    local available_mb
    available_mb=$(df -m /var | tail -1 | awk '{print $4}')

    if (( available_mb < MIN_DISK_SPACE_MB )); then
        print_error "Insufficient disk space in /var"
        print_error "Available: ${available_mb}MB, Required: ${MIN_DISK_SPACE_MB}MB"
        exit 1
    fi

    print_info "Disk space check: ${available_mb}MB available in /var"
}

# Check if netplan is available
check_netplan() {
    if ! command -v netplan &> /dev/null; then
        print_error "Netplan is not installed on this system"
        print_info "This script requires netplan for network configuration"
        exit 1
    fi

    print_success "Netplan available: $(netplan --version 2>&1 | head -1 || echo 'version unknown')"
}

# Check if ansible user already exists
check_ansible_user() {
    id "$ANSIBLE_USER" &>/dev/null
}

# Check if static IP is already configured
check_static_ip() {
    if [[ -z "$NETPLAN_CONFIG" ]]; then
        return 1
    fi

    if [[ -f "$NETPLAN_CONFIG" ]]; then
        if grep -q "dhcp4: false" "$NETPLAN_CONFIG" 2>/dev/null; then
            return 0  # Static configured
        fi
    fi
    return 1
}

################################################################################
# NETPLAN DETECTION FUNCTIONS
################################################################################

# Detect netplan configuration file
detect_netplan_config() {
    print_info "Detecting netplan configuration file..."

    if [[ ! -d "/etc/netplan" ]]; then
        print_error "Netplan directory not found: /etc/netplan"
        exit 1
    fi

    local netplan_files=()
    while IFS= read -r -d '' file; do
        if [[ ! "$file" =~ \.backup$ ]] && [[ ! "$file" =~ ~$ ]]; then
            netplan_files+=("$file")
        fi
    done < <(find /etc/netplan -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) -type f -print0 2>/dev/null)

    if [[ ${#netplan_files[@]} -eq 0 ]]; then
        print_warning "No netplan configuration files found in /etc/netplan/"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Create default netplan configuration? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml"
                print_info "Will create: $NETPLAN_CONFIG"
                return 0
            fi
        else
            NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml"
            print_warning "Non-interactive mode: will create $NETPLAN_CONFIG"
            return 0
        fi
        print_error "Cannot proceed without netplan configuration"
        exit 1
    fi

    if [[ ${#netplan_files[@]} -eq 1 ]]; then
        NETPLAN_CONFIG="${netplan_files[0]}"
        print_success "Found netplan config: ${GREEN}$(basename "$NETPLAN_CONFIG")${RESET}"
    else
        print_warning "Multiple netplan configuration files detected:"
        echo ""
        for i in "${!netplan_files[@]}"; do
            local file="${netplan_files[$i]}"
            local filesize
            filesize=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
            echo "  $((i+1))) $(basename "$file") (${filesize} bytes)"
        done
        echo ""

        if [[ "$INTERACTIVE" == true ]]; then
            echo "Select the netplan configuration file to use:"
            select file in "${netplan_files[@]}"; do
                if [[ -n "$file" ]]; then
                    NETPLAN_CONFIG="$file"
                    print_success "Selected: ${GREEN}$(basename "$NETPLAN_CONFIG")${RESET}"
                    break
                fi
            done
        else
            NETPLAN_CONFIG="${netplan_files[0]}"
            print_warning "Non-interactive mode: using first file: $(basename "$NETPLAN_CONFIG")"
        fi
    fi

    if [[ -r "$NETPLAN_CONFIG" ]]; then
        if ! grep -q "network:" "$NETPLAN_CONFIG" 2>/dev/null; then
            print_error "Selected file doesn't appear to be a valid netplan configuration"
            print_error "File: $NETPLAN_CONFIG"
            exit 1
        fi
    fi

    log "INFO" "Using netplan config: $NETPLAN_CONFIG"
    return 0
}

################################################################################
# NETWORK DETECTION FUNCTIONS
################################################################################

# Detect active network interface
detect_network_interface() {
    print_info "Detecting active network interface..."

    local interfaces
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | grep -v '^docker' | grep -v '^br-' | grep -v '^veth'))

    local active_interfaces=()
    for iface in "${interfaces[@]}"; do
        if ip addr show "$iface" 2>/dev/null | grep -q "state UP" && \
           ip addr show "$iface" 2>/dev/null | grep -q "inet "; then
            active_interfaces+=("$iface")
        fi
    done

    if [[ ${#active_interfaces[@]} -eq 0 ]]; then
        print_error "No active network interfaces found"
        exit 1
    elif [[ ${#active_interfaces[@]} -eq 1 ]]; then
        DETECTED_INTERFACE="${active_interfaces[0]}"
        print_success "Detected active interface: $DETECTED_INTERFACE"
    else
        print_warning "Multiple active interfaces detected: ${active_interfaces[*]}"
        echo ""
        for iface in "${active_interfaces[@]}"; do
            local ip_addr
            ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "no IP")
            echo "  - $iface: $ip_addr"
        done
        echo ""
        if [[ "$INTERACTIVE" == true ]]; then
            echo "Select network interface:"
            select iface in "${active_interfaces[@]}"; do
                if [[ -n "$iface" ]]; then
                    DETECTED_INTERFACE="$iface"
                    break
                fi
            done
        else
            DETECTED_INTERFACE="${active_interfaces[0]}"
            print_warning "Non-interactive mode: using first interface: $DETECTED_INTERFACE"
        fi
    fi

    CURRENT_IP=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
    MAC_ADDRESS=$(ip link show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=link/ether\s)[0-9a-f:]+' || echo "")

    if [[ -z "$CURRENT_IP" ]]; then
        print_error "No IP address found on interface $DETECTED_INTERFACE"
        exit 1
    fi

    print_info "Current IP: $CURRENT_IP"
    print_info "MAC Address: $MAC_ADDRESS"
    log "INFO" "Selected interface: $DETECTED_INTERFACE ($CURRENT_IP)"
}

# Get current gateway
detect_gateway() {
    DETECTED_GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1 || echo "")
    if [[ -n "$DETECTED_GATEWAY" ]]; then
        print_info "Detected gateway: $DETECTED_GATEWAY"
    else
        print_warning "Could not detect gateway"
        DETECTED_GATEWAY=""
    fi
}

################################################################################
# BACKUP FUNCTIONS
################################################################################

init_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    print_success "Backup directory initialized: $BACKUP_DIR"
    log "INFO" "Backup directory: $BACKUP_DIR"
}

backup_file() {
    local file="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="${BACKUP_DIR}/$(basename "$file").${timestamp}"

    if [[ -f "$file" ]]; then
        if cp -a "$file" "$backup_path" 2>/dev/null; then
            print_success "Backed up: $(basename "$file") → $(basename "$backup_path")"
            log "INFO" "Backup created: $backup_path"
            echo "$backup_path"
            return 0
        else
            print_error "Failed to create backup of: $file"
            return 1
        fi
    else
        log "INFO" "File not found for backup (will be created): $file"
        return 0
    fi
}

restore_backup() {
    local file="$1"
    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}/$(basename "$file")."* 2>/dev/null | head -n1 || true)

    if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup" ]]; then
        if cp -a "$latest_backup" "$file" 2>/dev/null; then
            print_success "Restored: $(basename "$file") from backup"
            log "INFO" "Rollback: Restored $file from $latest_backup"
            return 0
        else
            print_error "Failed to restore backup: $latest_backup"
            return 1
        fi
    else
        print_error "No backup found for: $file"
        return 1
    fi
}

################################################################################
# INTERACTIVE INPUT FUNCTIONS
################################################################################

prompt_hostname() {
    local current_hostname
    current_hostname=$(hostname)
    echo ""
    print_info "Current hostname: ${BOLD}$current_hostname${RESET}"
    echo ""

    while true; do
        read -p "Enter new hostname [press Enter to keep '$current_hostname']: " input_hostname
        if [[ -z "$input_hostname" ]]; then
            NEW_HOSTNAME="$current_hostname"
            print_info "Keeping current hostname: $NEW_HOSTNAME"
            break
        fi
        if validate_hostname "$input_hostname"; then
            NEW_HOSTNAME="$input_hostname"
            print_success "New hostname: $NEW_HOSTNAME"
            break
        else
            print_error "Invalid hostname format."
        fi
    done
}

prompt_static_ip() {
    echo ""

    if check_static_ip; then
        print_info "Current IP: ${BOLD}$CURRENT_IP${RESET} (${GREEN}Static${RESET})"
        print_success "Static IP already configured in netplan"
        echo ""
        read -p "Reconfigure static IP? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping current static IP configuration"
            STATIC_IP=""
            return
        fi
    else
        print_info "Current IP: ${BOLD}$CURRENT_IP${RESET} (${YELLOW}DHCP${RESET})"
        echo ""
        read -p "Configure static IP? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping DHCP configuration"
            STATIC_IP=""
            return
        fi
    fi

    while true; do
        read -p "Enter static IP address [$CURRENT_IP]: " input_ip
        input_ip="${input_ip:-$CURRENT_IP}"
        if validate_ip "$input_ip"; then
            STATIC_IP="$input_ip"
            break
        else
            print_error "Invalid IP address format"
        fi
    done

    while true; do
        read -p "Enter subnet mask [24]: " input_mask
        input_mask="${input_mask:-24}"
        if validate_subnet_mask "$input_mask"; then
            SUBNET_MASK="$input_mask"
            break
        else
            print_error "Invalid subnet mask (must be 1-32)"
        fi
    done

    while true; do
        if [[ -n "$DETECTED_GATEWAY" ]]; then
            read -p "Enter gateway [$DETECTED_GATEWAY]: " input_gateway
            input_gateway="${input_gateway:-$DETECTED_GATEWAY}"
        else
            read -p "Enter gateway: " input_gateway
        fi

        if validate_ip "$input_gateway"; then
            GATEWAY_IP="$input_gateway"
            break
        else
            print_error "Invalid gateway IP address"
        fi
    done

    while true; do
        read -p "Enter DNS server [$GATEWAY_IP]: " input_dns
        input_dns="${input_dns:-$GATEWAY_IP}"
        if validate_ip "$input_dns"; then
            DNS_SERVER="$input_dns"
            break
        else
            print_error "Invalid DNS server IP address"
        fi
    done

    print_success "Static IP configuration:"
    echo "  IP Address: $STATIC_IP/$SUBNET_MASK"
    echo "  Gateway: $GATEWAY_IP"
    echo "  DNS: $DNS_SERVER"
}

prompt_timezone() {
    echo ""
    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    print_info "Current timezone: ${BOLD}$current_tz${RESET}"
    echo ""

    read -p "Enter timezone [$DEFAULT_TIMEZONE]: " input_tz
    TIMEZONE="${input_tz:-$DEFAULT_TIMEZONE}"

    if timedatectl list-timezones 2>/dev/null | grep -q "^${TIMEZONE}$"; then
        print_success "Timezone: $TIMEZONE"
    else
        print_warning "Invalid timezone, using default: $DEFAULT_TIMEZONE"
        TIMEZONE="$DEFAULT_TIMEZONE"
    fi
}

prompt_ansible_user() {
    echo ""
    if check_ansible_user; then
        print_info "Ansible user '${BOLD}$ANSIBLE_USER${RESET}' already exists"
        read -p "Reconfigure ansible user? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CREATE_ANSIBLE_USER=true
        else
            CREATE_ANSIBLE_USER=false
            print_info "Keeping existing ansible user configuration"
        fi
    else
        print_info "Ansible user '${BOLD}$ANSIBLE_USER${RESET}' not found"
        read -p "Create ansible service account? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CREATE_ANSIBLE_USER=true
        else
            CREATE_ANSIBLE_USER=false
            print_warning "Skipping ansible user creation"
        fi
    fi
}

################################################################################
# CONFIG SUMMARY
################################################################################

display_config_summary() {
    print_header "Configuration Summary"

    echo -e "${BOLD}Hostname:${RESET}"
    if [[ "$(hostname)" != "$NEW_HOSTNAME" ]]; then
        echo "  Current: $(hostname)"
        echo "  New:     ${GREEN}$NEW_HOSTNAME${RESET}"
    else
        echo "  ${GREEN}$NEW_HOSTNAME${RESET} (no change)"
    fi

    echo ""
    echo -e "${BOLD}Network Configuration:${RESET}"
    echo "  Interface: $DETECTED_INTERFACE"

    if [[ -n "$STATIC_IP" ]]; then
        echo "  Current:   $CURRENT_IP (DHCP or existing)"
        echo "  New:       ${GREEN}$STATIC_IP/$SUBNET_MASK${RESET} (Static)"
        echo "  Gateway:   $GATEWAY_IP"
        echo "  DNS:       $DNS_SERVER"
    else
        echo "  ${GREEN}$CURRENT_IP${RESET} (no change)"
    fi

    echo ""
    echo -e "${BOLD}Ansible User:${RESET}"
    if [[ "$CREATE_ANSIBLE_USER" == true ]]; then
        if check_ansible_user; then
            echo "  ${YELLOW}Reconfigure existing user${RESET}"
        else
            echo "  ${GREEN}Create new user${RESET}"
        fi
    else
        if check_ansible_user; then
            echo "  ${GREEN}Exists${RESET} (no change)"
        else
            echo "  ${YELLOW}Will not be created${RESET}"
        fi
    fi

    echo ""
    echo -e "${BOLD}Timezone:${RESET}"
    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    if [[ "$current_tz" != "$TIMEZONE" ]]; then
        echo "  Current: $current_tz"
        echo "  New:     ${GREEN}$TIMEZONE${RESET}"
    else
        echo "  ${GREEN}$TIMEZONE${RESET} (no change)"
    fi

    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be applied"
        return 0
    fi

    read -p "Apply this configuration? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Configuration cancelled by user"
        exit 0
    fi
}

################################################################################
# APPLY CONFIGURATION
################################################################################

configure_hostname() {
    if [[ "$(hostname)" == "$NEW_HOSTNAME" ]]; then
        print_info "Hostname already set to: $NEW_HOSTNAME"
        return 0
    fi

    print_info "Configuring hostname: $NEW_HOSTNAME"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would set hostname to: $NEW_HOSTNAME"
        return 0
    fi

    backup_file "$HOSTS_FILE"

    if ! hostnamectl set-hostname "$NEW_HOSTNAME" 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Failed to set hostname"
        restore_backup "$HOSTS_FILE"
        return 1
    fi

    if grep -q "^127.0.1.1" "$HOSTS_FILE"; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" "$HOSTS_FILE"
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> "$HOSTS_FILE"
    fi

    print_success "Hostname configured: $NEW_HOSTNAME"
}

configure_ansible_user() {
    if [[ "$CREATE_ANSIBLE_USER" != true ]]; then
        log "INFO" "Skipping ansible user configuration (not requested)"
        return 0
    fi

    print_info "Configuring ansible service account"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would create/configure ansible user"
        return 0
    fi

    if ! check_ansible_user; then
        print_info "Creating ansible user..."
        if useradd -m -s /bin/bash "$ANSIBLE_USER" 2>&1 | tee -a "$LOG_FILE"; then
            passwd -l "$ANSIBLE_USER" &>/dev/null || true
            print_success "Ansible user created"
        else
            print_error "Failed to create ansible user"
            return 1
        fi
    else
        print_info "Ansible user already exists, configuring..."
    fi

    usermod -aG sudo "$ANSIBLE_USER" 2>&1 | tee -a "$LOG_FILE" || true

    echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ANSIBLE_USER"
    chmod 0440 "/etc/sudoers.d/$ANSIBLE_USER"

    if ! visudo -c -f "/etc/sudoers.d/$ANSIBLE_USER" &>/dev/null; then
        print_error "Invalid sudoers configuration"
        rm -f "/etc/sudoers.d/$ANSIBLE_USER"
        return 1
    fi

    local ansible_home="/home/$ANSIBLE_USER"
    mkdir -p "$ansible_home/.ssh"
    touch "$ansible_home/.ssh/authorized_keys"
    chmod 700 "$ansible_home/.ssh"
    chmod 600 "$ansible_home/.ssh/authorized_keys"
    chown -R "$ANSIBLE_USER:$ANSIBLE_USER" "$ansible_home/.ssh"

    print_success "Ansible user configured with passwordless sudo + SSH directory"
    print_warning "SSH public key must be added from the controller to: $ansible_home/.ssh/authorized_keys"
}

configure_timezone() {
    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")

    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        print_info "Timezone already set to: $TIMEZONE"
        return 0
    fi

    print_info "Configuring timezone: $TIMEZONE"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would set timezone to: $TIMEZONE"
        return 0
    fi

    timedatectl set-timezone "$TIMEZONE" 2>&1 | tee -a "$LOG_FILE"
    print_success "Timezone configured: $TIMEZONE"
}

# Configure static IP (LAST)
configure_static_ip() {
    if [[ -z "$STATIC_IP" ]]; then
        print_info "Keeping current DHCP configuration"
        return 0
    fi

    print_info "Configuring static IP: $STATIC_IP/$SUBNET_MASK"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would configure static IP: $STATIC_IP/$SUBNET_MASK"
        print_info "[DRY RUN] Gateway: $GATEWAY_IP"
        print_info "[DRY RUN] DNS: $DNS_SERVER"
        return 0
    fi

    if [[ -f "$NETPLAN_CONFIG" ]]; then
        backup_file "$NETPLAN_CONFIG"
    fi

    local mac_match=""
    if [[ -n "$MAC_ADDRESS" ]]; then
        mac_match="      match:
        macaddress: $MAC_ADDRESS
      set-name: $DETECTED_INTERFACE"
    fi

    cat > "$NETPLAN_CONFIG" <<EOF
# Static IP configuration for $NEW_HOSTNAME
# Generated by server-bootstrap.sh v${SCRIPT_VERSION}
# $(date '+%Y-%m-%d %H:%M:%S')
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

    if ! netplan generate 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Netplan configuration syntax error"
        print_warning "Restoring backup configuration..."
        restore_backup "$NETPLAN_CONFIG"
        return 1
    fi

    print_success "Netplan configuration created and validated"

    # ✅ FINAL confirmation before applying network changes (SSH may drop)
    if [[ "$INTERACTIVE" == true ]]; then
        echo ""
        print_warning "About to apply network configuration. This may disconnect your SSH session."
        print_info "After apply, reconnect to: ${STATIC_IP}"
        print_info "Example: ssh <your-user>@${STATIC_IP}"
        echo ""
        read -p "Apply network changes now? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Skipped applying netplan."
            print_info "Config file was written to: $NETPLAN_CONFIG"
            print_info "Apply later (recommended from console) with: sudo netplan apply"
            return 0
        fi
    fi

    print_warning "Applying network configuration - SSH may disconnect"
    print_info "Reconnect using: ssh <your-user>@$STATIC_IP"

    if timeout 30 netplan apply 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Static IP configured successfully"
        sleep 2

        local new_ip
        new_ip=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
        if [[ "$new_ip" == "$STATIC_IP" ]]; then
            print_success "Verified: Interface has new IP $STATIC_IP"
        else
            print_warning "IP verification: Expected $STATIC_IP, got $new_ip"
        fi
    else
        print_error "Failed to apply netplan configuration"
        print_warning "Attempting to restore backup..."
        restore_backup "$NETPLAN_CONFIG"
        netplan apply 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
}

################################################################################
# VERIFICATION
################################################################################

verify_configuration() {
    print_header "Verifying Configuration"

    local all_passed=true

    echo -n "Hostname: "
    if [[ "$(hostname)" == "$NEW_HOSTNAME" ]]; then
        echo -e "${GREEN}✓${RESET} $NEW_HOSTNAME"
    else
        echo -e "${RED}✗${RESET} Expected: $NEW_HOSTNAME, Got: $(hostname)"
        all_passed=false
    fi

    if check_ansible_user; then
        echo -e "Ansible user: ${GREEN}✓${RESET} exists"
    else
        if [[ "$CREATE_ANSIBLE_USER" == true ]]; then
            echo -e "Ansible user: ${RED}✗${RESET} not created"
            all_passed=false
        else
            echo -e "Ansible user: ${YELLOW}⚠${RESET} not requested"
        fi
    fi

    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    echo -n "Timezone: "
    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        echo -e "${GREEN}✓${RESET} $TIMEZONE"
    else
        echo -e "${RED}✗${RESET} Expected: $TIMEZONE, Got: $current_tz"
        all_passed=false
    fi

    if [[ -n "$STATIC_IP" ]]; then
        echo -n "Network target IP: "
        echo -e "${CYAN}${STATIC_IP}/${SUBNET_MASK}${RESET}"
    fi

    echo ""
    if [[ "$all_passed" == true ]]; then
        print_success "All core configurations verified successfully"
        return 0
    else
        print_warning "Some configurations may need verification or reboot"
        return 1
    fi
}

################################################################################
# MAIN SCRIPT LOGIC
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                print_warning "DRY RUN MODE ENABLED - No changes will be applied"
                shift
                ;;
            --hostname)
                NEW_HOSTNAME="$2"
                INTERACTIVE=false
                shift 2
                ;;
            --ip)
                STATIC_IP="$2"
                INTERACTIVE=false
                shift 2
                ;;
            --gateway)
                GATEWAY_IP="$2"
                shift 2
                ;;
            --dns)
                DNS_SERVER="$2"
                shift 2
                ;;
            --subnet|--mask)
                SUBNET_MASK="$2"
                shift 2
                ;;
            --timezone)
                TIMEZONE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<EOF
${BOLD}Server Bootstrap Script v${SCRIPT_VERSION}${RESET}

${BOLD}USAGE:${RESET}
    Interactive mode:
        sudo $0

    Non-interactive mode:
        sudo $0 --hostname NAME --ip IP --gateway GW [OPTIONS]

    Dry-run mode:
        sudo $0 --dry-run [OPTIONS]

${BOLD}OPTIONS:${RESET}
    --hostname NAME     Set server hostname
    --ip IP            Set static IP address
    --gateway IP       Set gateway IP
    --dns IP           Set DNS server IP (default: same as gateway)
    --subnet MASK      Set subnet mask (default: 24)
    --timezone TZ      Set timezone (default: ${DEFAULT_TIMEZONE})
    --dry-run          Test mode - show what would be done
    --help, -h         Show this help message

${BOLD}NEXT STEPS AFTER BOOTSTRAP:${RESET}
    From Ansible controller (NOT this server), add your controller public key:
      ssh-copy-id -i ${CONTROLLER_SSH_PUBKEY_HINT} ${ANSIBLE_USER}@<SERVER_IP>

EOF
}

main() {
    clear
    print_header "Server Bootstrap Script v${SCRIPT_VERSION}"

    parse_arguments "$@"

    check_root
    init_logging
    check_ubuntu
    check_disk_space
    check_netplan
    init_backup_dir

    detect_network_interface
    detect_netplan_config
    detect_gateway

    if [[ "$INTERACTIVE" == true ]]; then
        prompt_hostname
        prompt_static_ip
        prompt_timezone
        prompt_ansible_user
    else
        if [[ -z "$NEW_HOSTNAME" ]]; then
            NEW_HOSTNAME=$(hostname)
        fi

        if [[ -n "$STATIC_IP" ]]; then
            if ! validate_ip "$STATIC_IP"; then
                print_error "Invalid static IP: $STATIC_IP"
                exit 1
            fi

            if [[ -z "$GATEWAY_IP" ]]; then
                print_error "Gateway IP required when setting static IP"
                exit 1
            fi

            if ! validate_ip "$GATEWAY_IP"; then
                print_error "Invalid gateway IP: $GATEWAY_IP"
                exit 1
            fi

            if [[ -z "$DNS_SERVER" ]]; then
                DNS_SERVER="$GATEWAY_IP"
            fi

            if ! validate_subnet_mask "$SUBNET_MASK"; then
                print_error "Invalid subnet mask: $SUBNET_MASK"
                exit 1
            fi
        fi

        CREATE_ANSIBLE_USER=true
    fi

    display_config_summary

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "Dry run complete - no changes made"
        log "INFO" "Dry run completed successfully"
        exit 0
    fi

    print_header "Applying Configuration"

    # Non-disruptive steps first
    configure_hostname
    configure_timezone
    configure_ansible_user

    # ✅ Disruptive network change last
    configure_static_ip

    sleep 2
    verify_configuration || true

    print_header "Bootstrap Complete"
    print_success "Server bootstrap completed successfully!"
    echo ""
    echo "${BOLD}Next steps (from the Ansible controller):${RESET}"
    echo ""
    echo "  ${BOLD}1) Copy SSH public key to the server's ansible account:${RESET}"
    echo "     ${CYAN}ssh-copy-id -i ${CONTROLLER_SSH_PUBKEY_HINT} ${ANSIBLE_USER}@${STATIC_IP:-$CURRENT_IP}${RESET}"
    echo ""
    echo "  ${BOLD}2) Test Ansible connection:${RESET}"
    echo "     ${CYAN}ansible ${STATIC_IP:-$CURRENT_IP}, -m ping --user ${ANSIBLE_USER}${RESET}"
    echo ""
    echo "  ${BOLD}3) Add to Ansible inventory (on controller):${RESET}"
    echo "     ${CYAN}echo '${STATIC_IP:-$CURRENT_IP}   # $NEW_HOSTNAME' | sudo tee -a /etc/ansible/hosts${RESET}"
    echo ""

    if [[ -n "$STATIC_IP" ]]; then
        print_warning "Network configuration changed - reboot recommended"
        echo ""
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Reboot now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Rebooting system..."
                log "INFO" "System reboot initiated by user"
                reboot
            fi
        else
            print_info "Non-interactive mode: skipping reboot prompt."
        fi
    fi

    log "INFO" "=========================================="
    log "INFO" "Bootstrap completed successfully"
    log "INFO" "Hostname: $NEW_HOSTNAME"
    if [[ -n "$STATIC_IP" ]]; then
        log "INFO" "Static IP: $STATIC_IP/$SUBNET_MASK"
    fi
    log "INFO" "Ansible user: $(check_ansible_user && echo 'configured' || echo 'not created')"
    log "INFO" "=========================================="
}

main "$@"
