#!/bin/bash

################################################################################
# Server Bootstrap Script - Enterprise Homelab Initial Configuration
# 
# Purpose: Configure new Ubuntu servers with static IP, hostname, and ansible user
# Author: Noble's Homelab Automation
# Version: 2.3.0
# 
# Features:
#   - Auto-detect network interfaces and netplan configuration files
#   - Interactive or non-interactive modes
#   - Idempotent (safe to run multiple times)
#   - Comprehensive validation and error handling
#   - Automatic backups and rollback capability
#   - Detailed logging
#   - Dry-run mode for testing
#   - Advanced edge case handling
#
# Usage:
#   Interactive:   sudo ./server-bootstrap.sh
#   Non-interactive: sudo ./server-bootstrap.sh --hostname NAME --ip IP --gateway GW
#   Dry-run:       sudo ./server-bootstrap.sh --dry-run
#
################################################################################

set -euo pipefail  # Exit on error, undefined variables, pipe failures

################################################################################
# CONFIGURATION VARIABLES
################################################################################

SCRIPT_VERSION="2.3.0"
LOG_FILE="/var/log/server-bootstrap.log"
BACKUP_DIR="/var/backups/server-bootstrap"
NETPLAN_CONFIG=""  # Will be auto-detected
HOSTS_FILE="/etc/hosts"
ANSIBLE_USER="ansible"
DEFAULT_TIMEZONE="America/Chicago"
MIN_DISK_SPACE_MB=100  # Minimum free space required

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
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
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

# Validate CIDR notation
validate_cidr() {
    local cidr="$1"
    local ip_part="${cidr%/*}"
    local mask_part="${cidr#*/}"
    
    if ! validate_ip "$ip_part"; then
        return 1
    fi
    
    if [[ ! $mask_part =~ ^[0-9]+$ ]] || (( mask_part < 0 || mask_part > 32 )); then
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
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_warning "This script is designed for Ubuntu. You're running: $ID $VERSION"
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_warning "Non-interactive mode: proceeding with $ID"
        fi
    fi
    
    print_info "Detected OS: $PRETTY_NAME"
    log "INFO" "OS Details: $ID $VERSION_ID ($VERSION_CODENAME)"
}

# Check available disk space
check_disk_space() {
    local available_mb=$(df -m /var | tail -1 | awk '{print $4}')
    
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
        
        # Check for alternative network management
        if command -v nmcli &> /dev/null; then
            print_info "NetworkManager detected - consider using nmcli for configuration"
        elif systemctl is-active systemd-networkd &> /dev/null; then
            print_info "systemd-networkd detected - manual configuration required"
        fi
        
        exit 1
    fi
    
    print_success "Netplan available: $(netplan --version 2>&1 | head -1 || echo 'version unknown')"
}

# Check if ansible user already exists
check_ansible_user() {
    if id "$ANSIBLE_USER" &>/dev/null; then
        return 0  # User exists
    else
        return 1  # User doesn't exist
    fi
}

# Check if static IP is already configured
check_static_ip() {
    if [[ -z "$NETPLAN_CONFIG" ]]; then
        return 1
    fi
    
    if [[ -f "$NETPLAN_CONFIG" ]]; then
        if grep -q "dhcp4: false" "$NETPLAN_CONFIG" 2>/dev/null; then
            return 0  # Static IP configured
        fi
    fi
    return 1  # DHCP configured
}

################################################################################
# NETPLAN DETECTION FUNCTIONS
################################################################################

# Detect netplan configuration file
detect_netplan_config() {
    print_info "Detecting netplan configuration file..."
    
    # Check if /etc/netplan directory exists
    if [[ ! -d "/etc/netplan" ]]; then
        print_error "Netplan directory not found: /etc/netplan"
        print_warning "This system may not use netplan for network configuration"
        
        if [[ "$INTERACTIVE" == true ]]; then
            read -p "Create /etc/netplan directory and default config? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p /etc/netplan
                NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml"
                print_info "Will create: $NETPLAN_CONFIG"
                return 0
            fi
        fi
        exit 1
    fi
    
    # Find all .yaml and .yml files in /etc/netplan/
    local netplan_files=()
    while IFS= read -r -d '' file; do
        # Skip backup files
        if [[ ! "$file" =~ \.backup$ ]] && [[ ! "$file" =~ ~$ ]]; then
            netplan_files+=("$file")
        fi
    done < <(find /etc/netplan -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) -type f -print0 2>/dev/null)
    
    # Handle based on number of files found
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
            # Non-interactive: create default
            NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml"
            print_warning "Non-interactive mode: will create $NETPLAN_CONFIG"
            return 0
        fi
        
        print_error "Cannot proceed without netplan configuration"
        exit 1
    fi
    
    if [[ ${#netplan_files[@]} -eq 1 ]]; then
        # Single file found - use it automatically
        NETPLAN_CONFIG="${netplan_files[0]}"
        print_success "Found netplan config: ${GREEN}$(basename "$NETPLAN_CONFIG")${RESET}"
        
        # Show a preview of the file
        if [[ -r "$NETPLAN_CONFIG" ]]; then
            print_info "Current configuration preview:"
            echo ""
            if grep -E "dhcp4|dhcp6|addresses:" "$NETPLAN_CONFIG" 2>/dev/null | head -5 | sed 's/^/  /' | grep -q .; then
                grep -E "dhcp4|dhcp6|addresses:" "$NETPLAN_CONFIG" 2>/dev/null | head -5 | sed 's/^/  /'
            else
                print_warning "Unable to parse configuration preview"
            fi
            echo ""
        fi
        
    else
        # Multiple files found
        print_warning "Multiple netplan configuration files detected:"
        echo ""
        
        # Display files with details
        for i in "${!netplan_files[@]}"; do
            local file="${netplan_files[$i]}"
            local filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "unknown")
            local basename=$(basename "$file")
            echo "  $((i+1))) ${basename} (${filesize} bytes)"
            
            # Show if it's currently managing an interface
            if grep -q "dhcp4:\|addresses:" "$file" 2>/dev/null; then
                local iface=$(grep -A 5 "ethernets:" "$file" 2>/dev/null | grep -v "ethernets:" | grep ":" | head -1 | tr -d ' :' || echo "")
                if [[ -n "$iface" ]]; then
                    echo "       └─ Manages: $iface"
                fi
            fi
        done
        echo ""
        
        if [[ "$INTERACTIVE" == true ]]; then
            # Interactive selection
            echo "Select the netplan configuration file to use:"
            select file in "${netplan_files[@]}"; do
                if [[ -n "$file" ]]; then
                    NETPLAN_CONFIG="$file"
                    print_success "Selected: ${GREEN}$(basename "$NETPLAN_CONFIG")${RESET}"
                    break
                fi
            done
        else
            # Non-interactive - use first file and warn
            NETPLAN_CONFIG="${netplan_files[0]}"
            print_warning "Non-interactive mode: using first file: $(basename "$NETPLAN_CONFIG")"
            log "WARNING" "Multiple netplan files found, automatically selected: $NETPLAN_CONFIG"
        fi
    fi
    
    # Validate the selected file contains network configuration
    if [[ -r "$NETPLAN_CONFIG" ]]; then
        if ! grep -q "network:" "$NETPLAN_CONFIG" 2>/dev/null; then
            print_error "Selected file doesn't appear to be a valid netplan configuration"
            print_error "File: $NETPLAN_CONFIG"
            echo ""
            print_info "File contents:"
            cat "$NETPLAN_CONFIG" 2>/dev/null | head -10 | sed 's/^/  /'
            exit 1
        fi
    else
        print_warning "Cannot read netplan config file (will be created): $NETPLAN_CONFIG"
    fi
    
    # Display which interface is configured in this file
    if [[ -r "$NETPLAN_CONFIG" ]]; then
        local configured_interface=$(grep -A 5 "ethernets:" "$NETPLAN_CONFIG" 2>/dev/null | grep -v "ethernets:" | grep ":" | head -1 | tr -d ' :' || echo "")
        if [[ -n "$configured_interface" ]]; then
            print_info "Configured interface in file: ${BOLD}$configured_interface${RESET}"
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
    
    # Get list of interfaces that are UP and have an IP (excluding loopback and docker)
    local interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | grep -v '^docker' | grep -v '^br-' | grep -v '^veth'))
    local active_interfaces=()
    
    for iface in "${interfaces[@]}"; do
        # Check if interface is UP and has an IPv4 address
        if ip addr show "$iface" 2>/dev/null | grep -q "state UP" && \
           ip addr show "$iface" 2>/dev/null | grep -q "inet "; then
            active_interfaces+=("$iface")
        fi
    done
    
    if [[ ${#active_interfaces[@]} -eq 0 ]]; then
        print_error "No active network interfaces found"
        print_info "Available interfaces:"
        ip -o link show | awk -F': ' '{print "  - " $2}' | grep -v lo
        exit 1
    elif [[ ${#active_interfaces[@]} -eq 1 ]]; then
        DETECTED_INTERFACE="${active_interfaces[0]}"
        print_success "Detected active interface: $DETECTED_INTERFACE"
    else
        print_warning "Multiple active interfaces detected: ${active_interfaces[*]}"
        echo ""
        
        # Show details for each interface
        for iface in "${active_interfaces[@]}"; do
            local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "no IP")
            local state=$(ip link show "$iface" 2>/dev/null | grep -oP '(?<=state )\w+' || echo "unknown")
            echo "  - $iface: $ip ($state)"
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
            # Non-interactive: use first interface
            DETECTED_INTERFACE="${active_interfaces[0]}"
            print_warning "Non-interactive mode: using first interface: $DETECTED_INTERFACE"
        fi
    fi
    
    # Get current IP and MAC address
    CURRENT_IP=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
    MAC_ADDRESS=$(ip link show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=link/ether\s)[0-9a-f:]+' || echo "")
    
    if [[ -z "$CURRENT_IP" ]]; then
        print_error "No IP address found on interface $DETECTED_INTERFACE"
        exit 1
    fi
    
    print_info "Current IP: $CURRENT_IP"
    print_info "MAC Address: $MAC_ADDRESS"
    
    # Check if interface is managed by NetworkManager
    if command -v nmcli &> /dev/null; then
        if nmcli device show "$DETECTED_INTERFACE" 2>/dev/null | grep -q "GENERAL.STATE.*connected"; then
            print_warning "Interface appears to be managed by NetworkManager"
            print_warning "You may need to disable NetworkManager for this interface"
        fi
    fi
    
    log "INFO" "Selected interface: $DETECTED_INTERFACE ($CURRENT_IP)"
}

# Get current gateway
detect_gateway() {
    DETECTED_GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1 || echo "")
    if [[ -n "$DETECTED_GATEWAY" ]]; then
        print_info "Detected gateway: $DETECTED_GATEWAY"
        
        # Test gateway reachability
        if ping -c 1 -W 2 "$DETECTED_GATEWAY" &>/dev/null; then
            print_success "Gateway is reachable"
        else
            print_warning "Gateway is not responding to ping (may be normal)"
        fi
    else
        print_warning "Could not detect gateway"
        DETECTED_GATEWAY=""
    fi
}

################################################################################
# BACKUP FUNCTIONS
################################################################################

# Create backup directory
init_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    print_success "Backup directory initialized: $BACKUP_DIR"
    log "INFO" "Backup directory: $BACKUP_DIR"
}

# Backup configuration file
backup_file() {
    local file="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="${BACKUP_DIR}/$(basename "$file").${timestamp}"
    
    if [[ -f "$file" ]]; then
        if cp -a "$file" "$backup_path" 2>/dev/null; then
            print_success "Backed up: $(basename "$file") → $(basename "$backup_path")"
            log "INFO" "Backup created: $backup_path"
            echo "$backup_path"  # Return backup path
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

# Restore from backup (rollback)
restore_backup() {
    local file="$1"
    local latest_backup=$(ls -t "${BACKUP_DIR}/$(basename "$file")."* 2>/dev/null | head -n1)
    
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

# Get hostname from user
prompt_hostname() {
    local current_hostname=$(hostname)
    echo ""
    print_info "Current hostname: ${BOLD}$current_hostname${RESET}"
    echo ""
    
    while true; do
        read -p "Enter new hostname [press Enter to keep '$current_hostname']: " input_hostname
        
        # If empty, keep current hostname
        if [[ -z "$input_hostname" ]]; then
            NEW_HOSTNAME="$current_hostname"
            print_info "Keeping current hostname: $NEW_HOSTNAME"
            break
        fi
        
        # Validate hostname
        if validate_hostname "$input_hostname"; then
            NEW_HOSTNAME="$input_hostname"
            print_success "New hostname: $NEW_HOSTNAME"
            break
        else
            print_error "Invalid hostname format. Requirements:"
            echo "  - Lowercase letters, numbers, and hyphens only"
            echo "  - Must start and end with alphanumeric character"
            echo "  - Maximum 63 characters"
            echo "  - No underscores or special characters"
        fi
    done
}

# Get static IP configuration from user
prompt_static_ip() {
    echo ""
    
    # Check if static IP is already configured
    local ip_status="DHCP"
    local already_static=false
    
    if check_static_ip; then
        ip_status="Static"
        already_static=true
        print_info "Current IP: ${BOLD}$CURRENT_IP${RESET} (${GREEN}Static${RESET})"
        print_success "Static IP already configured in netplan"
        
        # Show current static configuration details
        if [[ -r "$NETPLAN_CONFIG" ]]; then
            local current_gateway=$(grep -A 10 "routes:" "$NETPLAN_CONFIG" 2>/dev/null | grep "via:" | head -1 | awk '{print $3}' || echo "unknown")
            local current_dns=$(grep -A 5 "nameservers:" "$NETPLAN_CONFIG" 2>/dev/null | grep -E "^\s+- [0-9]" | head -1 | awk '{print $2}' || echo "unknown")
            
            if [[ -n "$current_gateway" && "$current_gateway" != "unknown" ]]; then
                print_info "  Gateway: $current_gateway"
            fi
            if [[ -n "$current_dns" && "$current_dns" != "unknown" ]]; then
                print_info "  DNS: $current_dns"
            fi
        fi
        
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
    
    # Get static IP
    while true; do
        read -p "Enter static IP address [$CURRENT_IP]: " input_ip
        input_ip="${input_ip:-$CURRENT_IP}"
        
        if validate_ip "$input_ip"; then
            # Check if IP is on same network as current IP
            local current_network=$(echo "$CURRENT_IP" | cut -d. -f1-3)
            local new_network=$(echo "$input_ip" | cut -d. -f1-3)
            
            if [[ "$current_network" != "$new_network" ]] && [[ -n "$DETECTED_GATEWAY" ]]; then
                print_warning "IP is on different network than current ($current_network.0 vs $new_network.0)"
                read -p "Continue anyway? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            STATIC_IP="$input_ip"
            break
        else
            print_error "Invalid IP address format"
        fi
    done
    
    # Get subnet mask
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
    
    # Get gateway (with detected default)
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
    
    # Get DNS server (default to gateway)
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

# Get timezone from user
prompt_timezone() {
    echo ""
    local current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    print_info "Current timezone: ${BOLD}$current_tz${RESET}"
    echo ""
    
    read -p "Enter timezone [$DEFAULT_TIMEZONE]: " input_tz
    TIMEZONE="${input_tz:-$DEFAULT_TIMEZONE}"
    
    # Validate timezone
    if timedatectl list-timezones 2>/dev/null | grep -q "^${TIMEZONE}$"; then
        print_success "Timezone: $TIMEZONE"
    else
        print_warning "Invalid timezone, using default: $DEFAULT_TIMEZONE"
        TIMEZONE="$DEFAULT_TIMEZONE"
    fi
}

# Confirm ansible user creation
prompt_ansible_user() {
    echo ""
    if check_ansible_user; then
        print_info "Ansible user '${BOLD}$ANSIBLE_USER${RESET}' already exists"
        
        # Check sudo configuration
        local has_sudo=false
        if [[ -f "/etc/sudoers.d/$ANSIBLE_USER" ]]; then
            has_sudo=true
            print_info "  Passwordless sudo: configured"
        else
            print_warning "  Passwordless sudo: not configured"
        fi
        
        # Check SSH directory
        if [[ -d "/home/$ANSIBLE_USER/.ssh" ]]; then
            print_info "  SSH directory: exists"
        else
            print_warning "  SSH directory: not found"
        fi
        
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
            print_info "Note: Ansible automation will not work without this user"
        fi
    fi
}

################################################################################
# CONFIGURATION DISPLAY AND CONFIRMATION
################################################################################

# Display configuration summary
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
        echo "  Current:   $CURRENT_IP (DHCP)"
        echo "  New:       ${GREEN}$STATIC_IP/$SUBNET_MASK${RESET} (Static)"
        echo "  Gateway:   $GATEWAY_IP"
        echo "  DNS:       $DNS_SERVER"
    else
        echo "  ${GREEN}$CURRENT_IP${RESET} (DHCP - no change)"
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
    local current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
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
# CONFIGURATION APPLICATION FUNCTIONS
################################################################################

# Configure hostname
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
    
    # Backup hosts file
    backup_file "$HOSTS_FILE"
    
    # Set hostname
    if ! hostnamectl set-hostname "$NEW_HOSTNAME" 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Failed to set hostname"
        restore_backup "$HOSTS_FILE"
        return 1
    fi
    
    # Update /etc/hosts - handle both existing and new entries
    if grep -q "^127.0.1.1" "$HOSTS_FILE"; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" "$HOSTS_FILE"
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> "$HOSTS_FILE"
    fi
    
    print_success "Hostname configured: $NEW_HOSTNAME"
    log "INFO" "Hostname changed from $(cat /etc/hostname.bak 2>/dev/null || echo 'unknown') to $NEW_HOSTNAME"
}

# Configure static IP
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
    
    # Backup netplan config if it exists
    if [[ -f "$NETPLAN_CONFIG" ]]; then
        backup_file "$NETPLAN_CONFIG"
    fi
    
    # Get MAC address for matching (more reliable than interface name)
    local mac_match=""
    if [[ -n "$MAC_ADDRESS" ]]; then
        mac_match="      match:
        macaddress: $MAC_ADDRESS
      set-name: $DETECTED_INTERFACE"
    fi
    
    # Create new netplan configuration
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
    
    # Set proper permissions
    chmod 600 "$NETPLAN_CONFIG"
    
    # Validate netplan syntax
    if ! netplan generate 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Netplan configuration syntax error"
        if [[ -f "$NETPLAN_CONFIG.backup" ]]; then
            print_warning "Restoring backup configuration..."
            restore_backup "$NETPLAN_CONFIG"
        fi
        return 1
    fi
    
    print_success "Netplan configuration created and validated"
    print_warning "Applying network configuration - SSH may disconnect"
    print_info "Reconnect using: ssh user@$STATIC_IP"
    
    # Apply netplan with a timeout
    if timeout 30 netplan apply 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Static IP configured successfully"
        
        # Wait a moment for network to stabilize
        sleep 2
        
        # Verify new IP is assigned
        local new_ip=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
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

# Configure ansible user
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
    
    # Create user if doesn't exist
    if ! check_ansible_user; then
        print_info "Creating ansible user..."
        
        # Create user with disabled password login
        if useradd -m -s /bin/bash "$ANSIBLE_USER" 2>&1 | tee -a "$LOG_FILE"; then
            # Lock the password (SSH key authentication only)
            passwd -l "$ANSIBLE_USER" &>/dev/null
            print_success "Ansible user created"
        else
            print_error "Failed to create ansible user"
            return 1
        fi
    else
        print_info "Ansible user already exists, configuring..."
    fi
    
    # Add to sudo group
    if usermod -aG sudo "$ANSIBLE_USER" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Added to sudo group"
    else
        print_warning "Failed to add to sudo group (may already be member)"
    fi
    
    # Configure passwordless sudo
    echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ANSIBLE_USER"
    chmod 0440 "/etc/sudoers.d/$ANSIBLE_USER"
    
    # Verify sudoers syntax
    if ! visudo -c -f "/etc/sudoers.d/$ANSIBLE_USER" &>/dev/null; then
        print_error "Invalid sudoers configuration"
        rm -f "/etc/sudoers.d/$ANSIBLE_USER"
        return 1
    fi
    
    print_success "Passwordless sudo configured"
    
    # Create SSH directory with proper permissions
    local ansible_home="/home/$ANSIBLE_USER"
    if [[ ! -d "$ansible_home/.ssh" ]]; then
        mkdir -p "$ansible_home/.ssh"
        print_success "Created SSH directory"
    fi
    
    if [[ ! -f "$ansible_home/.ssh/authorized_keys" ]]; then
        touch "$ansible_home/.ssh/authorized_keys"
        print_success "Created authorized_keys file"
    fi
    
    # Set correct permissions
    chmod 700 "$ansible_home/.ssh"
    chmod 600 "$ansible_home/.ssh/authorized_keys"
    chown -R "$ANSIBLE_USER:$ANSIBLE_USER" "$ansible_home/.ssh"
    
    print_success "SSH directory configured with proper permissions"
    print_info "SSH directory: $ansible_home/.ssh"
    print_warning "Remember to add SSH public key to: $ansible_home/.ssh/authorized_keys"
    
    log "INFO" "Ansible user configured successfully"
}

# Detect which NTP service is installed/running
detect_ntp_service() {
    local detected_service=""
    
    # Check for chrony (common on Ubuntu Desktop, newer installs)
    if systemctl is-active chrony &>/dev/null || systemctl is-active chronyd &>/dev/null; then
        detected_service="chrony"
    # Check for systemd-timesyncd (common on Ubuntu Server)
    elif systemctl is-active systemd-timesyncd &>/dev/null; then
        detected_service="timesyncd"
    # Check for ntpd (older systems)
    elif systemctl is-active ntpd &>/dev/null || systemctl is-active ntp &>/dev/null; then
        detected_service="ntpd"
    # Check if chrony is installed but not running
    elif command -v chronyd &>/dev/null || systemctl list-unit-files | grep -q "^chrony.service"; then
        detected_service="chrony"
    # Check if timesyncd is available
    elif systemctl list-unit-files | grep -q "^systemd-timesyncd.service"; then
        detected_service="timesyncd"
    else
        detected_service="none"
    fi
    
    echo "$detected_service"
}

# Test if NTP servers are reachable
test_ntp_connectivity() {
    local test_server="time.google.com"
    
    print_info "Testing network connectivity to NTP servers..."
    
    # Test ping (ICMP)
    if ping -c 1 -W 2 "$test_server" &>/dev/null; then
        print_success "ICMP connectivity: OK"
        return 0
    else
        print_warning "ICMP (ping) blocked or unreachable"
        
        # Test if we can at least resolve DNS
        if nslookup "$test_server" &>/dev/null 2>&1 || host "$test_server" &>/dev/null 2>&1; then
            print_info "DNS resolution: OK"
            print_warning "NTP servers may be reachable via UDP even though ping fails"
            print_warning "This is common with firewall rules that block ICMP but allow NTP"
            return 0
        else
            print_error "Cannot resolve DNS - check network connectivity"
            return 1
        fi
    fi
}

# Sync time using chrony
sync_time_chrony() {
    print_info "Using chrony for time synchronization..."
    
    # Restart chrony to ensure clean state
    if systemctl restart chrony 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Chrony service restarted"
    else
        print_error "Failed to restart chrony"
        return 1
    fi
    
    # Force immediate sync attempts
    print_info "Forcing chrony to sync with NTP servers..."
    if chronyc burst 4/4 2>&1 | tee -a "$LOG_FILE"; then
        print_info "Chrony burst command sent"
    fi
    
    # Wait for sync attempt
    sleep 5
    
    # Force time step if needed
    if chronyc makestep 2>&1 | tee -a "$LOG_FILE"; then
        print_info "Chrony makestep command sent"
    fi
    
    # Wait a bit more for sync to complete
    sleep 5
    
    # Check if synchronized
    if chronyc tracking 2>&1 | grep -q "Leap status.*Normal"; then
        print_success "Chrony synchronized successfully"
        
        # Show tracking info
        local ref_id=$(chronyc tracking 2>/dev/null | grep "Reference ID" | awk '{print $4}')
        local stratum=$(chronyc tracking 2>/dev/null | grep "Stratum" | awk '{print $3}')
        
        if [[ -n "$ref_id" && "$ref_id" != "00000000" ]]; then
            print_info "Synced to: $ref_id (Stratum $stratum)"
        fi
        
        return 0
    else
        print_warning "Chrony may still be synchronizing"
        return 1
    fi
}

# Sync time using systemd-timesyncd
sync_time_timesyncd() {
    print_info "Using systemd-timesyncd for time synchronization..."
    
    # Enable NTP if not already enabled
    if ! timedatectl show -p NTP --value 2>/dev/null | grep -q "yes"; then
        if timedatectl set-ntp true 2>&1 | tee -a "$LOG_FILE"; then
            print_success "NTP enabled via timedatectl"
        fi
    fi
    
    # Ensure service is enabled
    if ! systemctl is-enabled systemd-timesyncd &>/dev/null; then
        if systemctl enable systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"; then
            print_success "systemd-timesyncd service enabled"
        fi
    fi
    
    # Restart service to force sync
    if systemctl restart systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"; then
        print_success "systemd-timesyncd service restarted"
    else
        print_error "Failed to restart systemd-timesyncd"
        return 1
    fi
    
    # Wait for sync
    print_info "Waiting for time synchronization..."
    local max_wait=15
    local waited=0
    
    while (( waited < max_wait )); do
        sleep 2
        waited=$((waited + 2))
        
        if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q "yes"; then
            print_success "systemd-timesyncd synchronized successfully"
            return 0
        fi
    done
    
    print_warning "Synchronization taking longer than expected"
    return 1
}

# Sync time using ntpd
sync_time_ntpd() {
    print_info "Using ntpd for time synchronization..."
    
    # Restart ntpd
    if systemctl restart ntpd 2>&1 | tee -a "$LOG_FILE" || systemctl restart ntp 2>&1 | tee -a "$LOG_FILE"; then
        print_success "ntpd service restarted"
    else
        print_error "Failed to restart ntpd"
        return 1
    fi
    
    # Wait for sync
    sleep 10
    
    # Check if ntpd is syncing (this varies by implementation)
    if ntpq -p 2>/dev/null | grep -q "^\*"; then
        print_success "ntpd synchronized successfully"
        return 0
    else
        print_warning "ntpd may still be synchronizing"
        return 1
    fi
}

# Manual time sync fallback
manual_time_sync() {
    print_warning "Attempting manual time synchronization..."
    
    # Check if ntpdate is available (full path)
    local ntpdate_cmd=""
    if [[ -x "/usr/sbin/ntpdate" ]]; then
        ntpdate_cmd="/usr/sbin/ntpdate"
    elif command -v ntpdate &>/dev/null; then
        ntpdate_cmd="ntpdate"
    elif command -v ntpdig &>/dev/null; then
        ntpdate_cmd="ntpdig -s"
    fi
    
    if [[ -n "$ntpdate_cmd" ]]; then
        print_info "Found time sync tool: $ntpdate_cmd"
        
        # Try to sync
        if $ntpdate_cmd pool.ntp.org 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Manual time sync completed"
            return 0
        elif $ntpdate_cmd time.google.com 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Manual time sync completed (Google)"
            return 0
        else
            print_error "Manual time sync failed"
            return 1
        fi
    else
        print_warning "No manual sync tool available"
        print_info "Install ntpsec-ntpdate: apt update && apt install -y ntpsec-ntpdate"
        print_info "Then run: /usr/sbin/ntpdate pool.ntp.org"
        return 1
    fi
}

# Configure timezone and time synchronization
configure_timezone() {
    local current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    
    # Set timezone if different
    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        print_info "Timezone already set to: $TIMEZONE"
    else
        print_info "Configuring timezone: $TIMEZONE"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY RUN] Would set timezone to: $TIMEZONE"
        else
            if timedatectl set-timezone "$TIMEZONE" 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Timezone configured: $TIMEZONE"
                
                # Display current time
                local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
                print_info "Current time: $current_time"
            else
                print_error "Failed to set timezone"
                return 1
            fi
        fi
    fi
    
    echo ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Configuring Time Synchronization"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would configure time synchronization"
        return 0
    fi
    
    # Detect which NTP service is available
    local ntp_service=$(detect_ntp_service)
    print_info "Detected NTP service: $ntp_service"
    
    # Test network connectivity
    if ! test_ntp_connectivity; then
        print_error "Network connectivity issue detected"
        print_warning "Time synchronization may fail due to:"
        print_warning "  - Firewall blocking NTP traffic (UDP port 123)"
        print_warning "  - No internet connectivity"
        print_warning "  - DNS resolution failures"
        echo ""
        print_info "If using pfSense or firewall:"
        print_info "  - Ensure UDP port 123 outbound is allowed"
        print_info "  - Check Firewall → Rules → [Your VLAN]"
        print_info "  - Add rule: Protocol=Any, Destination=Any (or UDP/123 specifically)"
        echo ""
    fi
    
    # Attempt sync based on detected service
    local sync_success=false
    
    case "$ntp_service" in
        "chrony")
            print_success "Using chrony for time synchronization"
            if sync_time_chrony; then
                sync_success=true
            fi
            ;;
        "timesyncd")
            print_success "Using systemd-timesyncd for time synchronization"
            if sync_time_timesyncd; then
                sync_success=true
            fi
            ;;
        "ntpd")
            print_success "Using ntpd for time synchronization"
            if sync_time_ntpd; then
                sync_success=true
            fi
            ;;
        "none")
            print_warning "No NTP service detected"
            print_info "Installing systemd-timesyncd..."
            
            if apt update &>/dev/null && apt install -y systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"; then
                print_success "systemd-timesyncd installed"
                if sync_time_timesyncd; then
                    sync_success=true
                fi
            else
                print_error "Failed to install systemd-timesyncd"
            fi
            ;;
    esac
    
    # If automatic sync failed, try manual sync
    if [[ "$sync_success" != true ]]; then
        print_warning "Automatic time sync did not complete successfully"
        print_info "Attempting manual time synchronization..."
        
        if manual_time_sync; then
            sync_success=true
            
            # Restart the NTP service after manual sync
            case "$ntp_service" in
                "chrony")
                    systemctl restart chrony 2>&1 | tee -a "$LOG_FILE"
                    ;;
                "timesyncd")
                    systemctl restart systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"
                    ;;
                "ntpd")
                    systemctl restart ntpd 2>&1 | tee -a "$LOG_FILE" || systemctl restart ntp 2>&1 | tee -a "$LOG_FILE"
                    ;;
            esac
        fi
    fi
    
    # Display final time status
    echo ""
    print_info "Time configuration summary:"
    timedatectl status | grep -E "Local time|Time zone|System clock|NTP service" | sed 's/^/  /' | tee -a "$LOG_FILE"
    
    echo ""
    local synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo "no")
    if [[ "$synced" == "yes" ]] || [[ "$sync_success" == true ]]; then
        print_success "Time synchronization completed successfully"
        local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
        print_success "Current time: $current_time"
    else
        print_warning "Time synchronization may still be in progress"
        print_info "Check status with: timedatectl status"
        print_info "Check service with: systemctl status $ntp_service"
        
        if [[ "$ntp_service" == "chrony" ]]; then
            print_info "Check chrony tracking: sudo chronyc tracking"
            print_info "View chrony sources: sudo chronyc sources"
        fi
        
        echo ""
        print_warning "If time sync continues to fail:"
        print_info "  1. Check firewall allows UDP port 123 outbound"
        print_info "  2. Verify internet connectivity: ping 8.8.8.8"
        print_info "  3. Test NTP manually: sudo /usr/sbin/ntpdate pool.ntp.org"
        print_info "  4. Check service logs: journalctl -u $ntp_service -n 50"
    fi
    
    log "INFO" "Timezone and time sync configuration completed"
}

################################################################################
# VERIFICATION FUNCTIONS
################################################################################

# Verify configuration
verify_configuration() {
    print_header "Verifying Configuration"
    
    local all_passed=true
    
    # Check hostname
    echo -n "Hostname: "
    if [[ "$(hostname)" == "$NEW_HOSTNAME" ]]; then
        echo -e "${GREEN}✓${RESET} $NEW_HOSTNAME"
    else
        echo -e "${RED}✗${RESET} Expected: $NEW_HOSTNAME, Got: $(hostname)"
        all_passed=false
    fi
    
    # Check static IP (if configured)
    if [[ -n "$STATIC_IP" ]]; then
        echo -n "Static IP: "
        local current_ip=$(ip -4 addr show "$DETECTED_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "")
        local expected_ip="$STATIC_IP/$SUBNET_MASK"
        
        if [[ "$current_ip" == "$expected_ip" ]]; then
            echo -e "${GREEN}✓${RESET} $current_ip"
        else
            echo -e "${YELLOW}⚠${RESET} Expected: $expected_ip, Got: $current_ip (may need reboot)"
        fi
        
        # Check gateway
        echo -n "Gateway: "
        local current_gw=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1 || echo "")
        if [[ "$current_gw" == "$GATEWAY_IP" ]]; then
            echo -e "${GREEN}✓${RESET} $GATEWAY_IP"
        else
            echo -e "${YELLOW}⚠${RESET} Expected: $GATEWAY_IP, Got: $current_gw"
        fi
    fi
    
    # Check ansible user
    echo -n "Ansible user: "
    if check_ansible_user; then
        echo -e "${GREEN}✓${RESET} exists"
        
        # Check sudo configuration
        echo -n "  Passwordless sudo: "
        if [[ -f "/etc/sudoers.d/$ANSIBLE_USER" ]]; then
            echo -e "${GREEN}✓${RESET} configured"
        else
            echo -e "${RED}✗${RESET} not configured"
            all_passed=false
        fi
        
        # Check SSH directory
        echo -n "  SSH directory: "
        if [[ -d "/home/$ANSIBLE_USER/.ssh" ]]; then
            echo -e "${GREEN}✓${RESET} exists"
            
            # Check permissions
            local ssh_perm=$(stat -c%a "/home/$ANSIBLE_USER/.ssh" 2>/dev/null)
            if [[ "$ssh_perm" == "700" ]]; then
                echo -e "    Permissions: ${GREEN}✓${RESET} 700"
            else
                echo -e "    Permissions: ${YELLOW}⚠${RESET} $ssh_perm (expected 700)"
            fi
        else
            echo -e "${RED}✗${RESET} not found"
            all_passed=false
        fi
    else
        if [[ "$CREATE_ANSIBLE_USER" == true ]]; then
            echo -e "${RED}✗${RESET} not created"
            all_passed=false
        else
            echo -e "${YELLOW}⚠${RESET} not requested"
        fi
    fi
    
    # Check timezone
    echo -n "Timezone: "
    local current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    if [[ "$current_tz" == "$TIMEZONE" ]]; then
        echo -e "${GREEN}✓${RESET} $TIMEZONE"
    else
        echo -e "${RED}✗${RESET} Expected: $TIMEZONE, Got: $current_tz"
        all_passed=false
    fi
    
    # Check time synchronization
    echo -n "Time sync (NTP): "
    local ntp_enabled=$(timedatectl show -p NTP --value 2>/dev/null || echo "no")
    local ntp_synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo "no")
    local ntp_service=$(detect_ntp_service)
    
    if [[ "$ntp_enabled" == "yes" ]] || [[ "$ntp_service" != "none" ]]; then
        if [[ "$ntp_synced" == "yes" ]]; then
            echo -e "${GREEN}✓${RESET} enabled and synchronized"
        else
            # Check if chrony is synced (alternative check)
            if [[ "$ntp_service" == "chrony" ]]; then
                if chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal"; then
                    echo -e "${GREEN}✓${RESET} chrony synchronized"
                else
                    echo -e "${YELLOW}⚠${RESET} enabled, waiting for sync (using $ntp_service)"
                fi
            else
                echo -e "${YELLOW}⚠${RESET} enabled, waiting for sync (using $ntp_service)"
            fi
        fi
    else
        echo -e "${RED}✗${RESET} not enabled"
        all_passed=false
    fi
    
    # Display current time
    echo -n "Current time: "
    local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo -e "${CYAN}$current_time${RESET}"
    
    echo ""
    
    if [[ "$all_passed" == true ]]; then
        print_success "All configurations verified successfully"
        return 0
    else
        print_warning "Some configurations may need verification or reboot"
        return 1
    fi
}

################################################################################
# MAIN SCRIPT LOGIC
################################################################################

# Parse command line arguments
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

# Show help
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
    --timezone TZ      Set timezone (default: America/Chicago)
    --dry-run          Test mode - show what would be done
    --help, -h         Show this help message

${BOLD}EXAMPLES:${RESET}
    # Interactive mode (recommended)
    sudo $0
    
    # Configure hostname and static IP
    sudo $0 --hostname lab-devops-svc01 --ip 192.168.40.2 --gateway 192.168.40.1
    
    # With custom subnet mask
    sudo $0 --hostname lab-web-01 --ip 10.0.1.50 --gateway 10.0.1.1 --subnet 16
    
    # Dry run to see what would change
    sudo $0 --dry-run --hostname lab-test-01 --ip 192.168.10.50
    
    # Set only hostname and timezone
    sudo $0 --hostname lab-core-db01 --timezone America/New_York

${BOLD}FEATURES:${RESET}
    • Auto-detect network interfaces and netplan files
    • Idempotent (safe to re-run)
    • Automatic configuration backups
    • Comprehensive validation and error handling
    • Detailed logging to $LOG_FILE
    • Rollback on failure
    • Handles multiple edge cases

${BOLD}FILES:${RESET}
    Log file:    $LOG_FILE
    Backups:     $BACKUP_DIR
    Netplan:     Auto-detected in /etc/netplan/

${BOLD}NEXT STEPS AFTER BOOTSTRAP:${RESET}
    1. Add SSH key for ansible user (from controller):
       ssh-copy-id -i ~/.ssh/ansible-automation-key.pub ansible@${STATIC_IP:-$CURRENT_IP}
    
    2. Test Ansible connection:
       ansible <NEW_IP>, -m ping --user ansible
    
    3. Add to Ansible inventory:
       echo '<NEW_IP>   # <HOSTNAME>' >> /etc/ansible/hosts

EOF
}

# Main function
main() {
    # Print banner
    clear
    print_header "Server Bootstrap Script v${SCRIPT_VERSION}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Pre-flight checks
    check_root
    init_logging
    check_ubuntu
    check_disk_space
    check_netplan
    init_backup_dir
    
    # Detect current configuration
    detect_network_interface
    detect_netplan_config
    detect_gateway
    
    # Get configuration (interactive or from parameters)
    if [[ "$INTERACTIVE" == true ]]; then
        prompt_hostname
        prompt_static_ip
        prompt_timezone
        prompt_ansible_user
    else
        # Validate non-interactive parameters
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
        
        # Always create ansible user in non-interactive mode
        CREATE_ANSIBLE_USER=true
    fi
    
    # Display configuration summary and get confirmation
    display_config_summary
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "Dry run complete - no changes made"
        log "INFO" "Dry run completed successfully"
        exit 0
    fi
    
    # Apply configurations
    print_header "Applying Configuration"
    
    configure_hostname
    configure_timezone
    configure_ansible_user
    configure_static_ip  # Do this last as it may disconnect network
    
    # Verify configuration
    sleep 2
    verify_configuration
    
    # Final summary
    print_header "Bootstrap Complete"
    
    print_success "Server bootstrap completed successfully!"
    echo ""
    echo "${BOLD}Next steps:${RESET}"
    echo ""
    echo "  ${BOLD}1. Add SSH key${RESET} for ansible user:"
    echo "     ${CYAN}From Ansible controller:${RESET}"
    echo "     ssh-copy-id -i ~/.ssh/ansible-homelab-key.pub ansible@${STATIC_IP:-$CURRENT_IP}"
    echo ""
    echo "  ${BOLD}2. Test Ansible connection:${RESET}"
    echo "     ansible ${STATIC_IP:-$CURRENT_IP}, -m ping --user ansible"
    echo ""
    echo "  ${BOLD}3. Add to Ansible inventory:${RESET}"
    echo "     echo '${STATIC_IP:-$CURRENT_IP}   # $NEW_HOSTNAME' >> /etc/ansible/hosts"
    echo ""
    
    if [[ -n "$STATIC_IP" ]]; then
        print_warning "Network configuration changed - reboot recommended"
        echo ""
        read -p "Reboot now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rebooting system..."
            log "INFO" "System reboot initiated by user"
            reboot
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

# Run main function with all arguments
main "$@"