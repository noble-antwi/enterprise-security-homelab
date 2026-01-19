#!/bin/bash
################################################################################
# Ansible Server Finalization Script
# 
# Purpose: Completes Ansible integration after server-bootstrap.sh has run
# Version: 1.1.0
# Runs FROM: Ansible Controller
# Runs TO: New server that has been bootstrapped
#
# What it does:
#   1. Copies SSH key to ansible user (via another user with access)
#   2. Tests ansible SSH connectivity
#   3. Tests passwordless sudo
#   4. Adds server to Ansible inventory
#   5. Verifies Ansible can manage the server
#
# Prerequisites:
#   - server-bootstrap.sh has been run on target server
#   - ansible user exists on target server
#   - You have a user account with password/key access to target server
#   - Ansible is installed on this controller
#
################################################################################

set -euo pipefail

# Script version
SCRIPT_VERSION="1.1.0"

# Configuration with fallbacks
ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
ANSIBLE_KEY="${ANSIBLE_SSH_KEY:-$HOME/.ssh/ansible-automation-key}"
INVENTORY_FILE="${ANSIBLE_INVENTORY:-/etc/ansible/hosts}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Log file
LOG_FILE="/tmp/ansible-finalize-$(date +%Y%m%d-%H%M%S).log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'
NC='\033[0m'

# State tracking for rollback
ADDED_TO_INVENTORY=false
SERVER_IP_GLOBAL=""

# Print functions
print_success() { echo -e "${GREEN}✓${RESET} $*" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}✗${RESET} $*" | tee -a "$LOG_FILE"; }
print_info() { echo -e "${BLUE}ℹ${RESET} $*" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}⚠${RESET} $*" | tee -a "$LOG_FILE"; }
print_header() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${CYAN}  $*${RESET}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Show usage
show_usage() {
    cat <<EOF
${BOLD}Ansible Server Finalization Script v${SCRIPT_VERSION}${NC}

${BOLD}PURPOSE:${NC}
    Complete Ansible integration after running server-bootstrap.sh on target server.
    This script copies SSH keys, tests connectivity, and adds server to inventory.

${BOLD}PREREQUISITES:${NC}
    1. server-bootstrap.sh has been run on target server
    2. 'ansible' user exists on target server with:
       - Passwordless sudo configured
       - SSH directory created
    3. You have access to target server via another user (with password or key)
    4. Ansible is installed on this controller

${BOLD}USAGE:${NC}
    Interactive mode (recommended):
        $0

    Non-interactive mode:
        $0 <server_ip> <bootstrap_user> [hostname]

    Dry-run mode:
        DRY_RUN=true $0 192.168.10.7 vagrant

    Verbose mode:
        VERBOSE=true $0 192.168.10.7 vagrant

    Custom SSH key:
        ANSIBLE_SSH_KEY=~/.ssh/custom-key $0 192.168.10.7 vagrant

${BOLD}EXAMPLES:${NC}
    # Interactive - prompts for all information
    $0

    # Specify server IP and user
    $0 192.168.10.7 vagrant

    # Specify everything
    $0 192.168.10.7 ubuntu lab-web-01

    # Test without making changes
    DRY_RUN=true $0 192.168.10.7 vagrant

${BOLD}ENVIRONMENT VARIABLES:${NC}
    ANSIBLE_SSH_KEY      Path to ansible SSH private key (default: ~/.ssh/ansible-automation-key)
    ANSIBLE_USER         Ansible username (default: ansible)
    ANSIBLE_INVENTORY    Inventory file path (default: /etc/ansible/hosts)
    DRY_RUN              Test without making changes (default: false)
    VERBOSE              Enable verbose output (default: false)

${BOLD}WHAT IS ASKED:${NC}
    - Target server IP address (e.g., 192.168.10.7)
    - Bootstrap username (user with access: vagrant, ubuntu, nantwi, etc.)
    - Server hostname (optional - will auto-detect if not provided)

${BOLD}LOG FILE:${NC}
    All operations are logged to: $LOG_FILE

EOF
}

# Rollback function
rollback() {
    if [[ "$ADDED_TO_INVENTORY" == true ]] && [[ -n "$SERVER_IP_GLOBAL" ]]; then
        print_warning "Rolling back changes..."
        
        if [[ -f "$INVENTORY_FILE" ]]; then
            if sudo sed -i.bak "/^$SERVER_IP_GLOBAL/d" "$INVENTORY_FILE" 2>/dev/null; then
                print_info "Removed $SERVER_IP_GLOBAL from inventory"
            fi
        fi
    fi
}

# Set trap for cleanup
trap rollback ERR

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing=()
    
    # Check if ansible is installed
    if ! command -v ansible &>/dev/null; then
        missing+=("ansible")
    fi
    
    # Check if ssh is available
    if ! command -v ssh &>/dev/null; then
        missing+=("ssh")
    fi
    
    # Check if required tools exist
    for tool in grep sed awk tee; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing[*]}"
        print_info "Install with: sudo apt install ansible openssh-client"
        return 1
    fi
    
    print_success "All prerequisites installed"
    return 0
}

# Check if SSH key exists
check_ssh_key() {
    print_info "Checking SSH key: ${ANSIBLE_KEY}"
    
    if [[ ! -f "${ANSIBLE_KEY}" ]]; then
        print_error "SSH private key not found: ${ANSIBLE_KEY}"
        echo ""
        print_info "Please generate SSH keys first:"
        echo "  ssh-keygen -t ed25519 -f ${ANSIBLE_KEY} -C 'ansible-automation'"
        echo ""
        return 1
    fi
    
    if [[ ! -f "${ANSIBLE_KEY}.pub" ]]; then
        print_error "SSH public key not found: ${ANSIBLE_KEY}.pub"
        echo ""
        print_info "Public key should exist alongside private key"
        return 1
    fi
    
    # Check key permissions
    local key_perms=$(stat -c%a "${ANSIBLE_KEY}" 2>/dev/null)
    if [[ "$key_perms" != "600" ]]; then
        print_warning "SSH key has incorrect permissions: $key_perms (should be 600)"
        print_info "Fixing permissions..."
        chmod 600 "${ANSIBLE_KEY}"
        print_success "Permissions corrected"
    fi
    
    print_success "SSH key exists: ${ANSIBLE_KEY}"
    return 0
}

# Validate IP address format
validate_ip() {
    local ip="$1"
    
    # Check basic IP format
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Check each octet is 0-255
        local IFS='.'
        local -a octets=($ip)
        
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                print_error "Invalid IP address: $ip (octet $octet > 255)"
                return 1
            fi
        done
        
        return 0
    else
        print_error "Invalid IP address format: $ip"
        print_info "Expected format: xxx.xxx.xxx.xxx"
        return 1
    fi
}

# Auto-detect inventory file
detect_inventory_file() {
    # Try ansible-config if available
    if command -v ansible-config &>/dev/null; then
        local detected=$(ansible-config dump 2>/dev/null | grep -i "DEFAULT_HOST_LIST" | awk '{print $3}' | tr -d '"' || echo "")
        if [[ -n "$detected" ]] && [[ -f "$detected" ]]; then
            echo "$detected"
            return 0
        fi
    fi
    
    # Check common locations
    local common_locations=(
        "/etc/ansible/hosts"
        "$HOME/.ansible/hosts"
        "./inventory"
        "./hosts"
    )
    
    for location in "${common_locations[@]}"; do
        if [[ -f "$location" ]]; then
            echo "$location"
            return 0
        fi
    done
    
    # Default
    echo "/etc/ansible/hosts"
}

# Prompt for server details
get_server_details() {
    local server_ip="$1"
    local bootstrap_user="$2"
    local hostname="$3"
    
    # Get server IP
    if [[ -z "$server_ip" ]]; then
        echo ""
        print_info "Enter target server details"
        echo ""
        
        while true; do
            read -p "Server IP address: " server_ip
            
            if [[ -z "$server_ip" ]]; then
                print_error "Server IP is required"
                continue
            fi
            
            if validate_ip "$server_ip"; then
                break
            fi
        done
    else
        if ! validate_ip "$server_ip"; then
            exit 1
        fi
    fi
    
    # Get bootstrap username
    if [[ -z "$bootstrap_user" ]]; then
        echo ""
        print_info "Enter the username of a user with access to the server"
        print_info "This user will be used to copy the SSH key to the ansible user"
        echo ""
        print_warning "Common usernames: vagrant, ubuntu, nantwi, admin, your-name"
        echo ""
        read -p "Bootstrap username: " bootstrap_user
        
        if [[ -z "$bootstrap_user" ]]; then
            print_error "Bootstrap username is required"
            exit 1
        fi
    fi
    
    # Hostname will be auto-detected if not provided
    
    echo "$server_ip|$bootstrap_user|$hostname"
}

# Test basic connectivity
test_connectivity() {
    local server_ip="$1"
    local bootstrap_user="$2"
    
    print_info "Testing connectivity to $bootstrap_user@$server_ip..."
    
    # Use accept-new for better security than no checking
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$bootstrap_user@$server_ip" "echo 'Connected'" &>/dev/null; then
        print_success "Can connect to server as $bootstrap_user"
        return 0
    else
        print_error "Cannot connect to $bootstrap_user@$server_ip"
        echo ""
        print_info "Please verify:"
        echo "  - Server is online: ping $server_ip"
        echo "  - IP address is correct: $server_ip"
        echo "  - Username is correct: $bootstrap_user"
        echo "  - You can SSH manually: ssh $bootstrap_user@$server_ip"
        echo "  - Firewall allows SSH (port 22)"
        echo ""
        return 1
    fi
}

# Check if ansible user exists on target
check_ansible_user_exists() {
    local server_ip="$1"
    local bootstrap_user="$2"
    
    print_info "Checking if '$ANSIBLE_USER' user exists on target server..."
    
    if ssh -o StrictHostKeyChecking=accept-new "$bootstrap_user@$server_ip" "id $ANSIBLE_USER &>/dev/null" 2>/dev/null; then
        print_success "Ansible user exists on target server"
        
        # Check if SSH directory exists
        if ssh "$bootstrap_user@$server_ip" "sudo test -d /home/$ANSIBLE_USER/.ssh" 2>/dev/null; then
            print_success "Ansible user has .ssh directory"
            
            # Check permissions
            local ssh_perms=$(ssh "$bootstrap_user@$server_ip" "sudo stat -c%a /home/$ANSIBLE_USER/.ssh" 2>/dev/null || echo "")
            if [[ "$ssh_perms" == "700" ]]; then
                print_success ".ssh directory has correct permissions (700)"
            else
                print_warning ".ssh directory permissions: $ssh_perms (expected 700)"
            fi
        else
            print_warning "Ansible user exists but .ssh directory not found"
            print_info "Did you run server-bootstrap.sh on the target server?"
            return 1
        fi
        
        # Check if passwordless sudo is configured
        if ssh "$bootstrap_user@$server_ip" "sudo test -f /etc/sudoers.d/$ANSIBLE_USER" 2>/dev/null; then
            print_success "Passwordless sudo is configured"
        else
            print_warning "Passwordless sudo may not be configured"
            print_info "Check: /etc/sudoers.d/$ANSIBLE_USER on target server"
        fi
        
        return 0
    else
        print_error "Ansible user does NOT exist on target server"
        echo ""
        print_warning "You must run server-bootstrap.sh on the target server first!"
        echo ""
        print_info "On the target server, run:"
        echo "  sudo ./server-bootstrap.sh"
        echo ""
        return 1
    fi
}

# Check if SSH key already exists
check_existing_key() {
    local server_ip="$1"
    local bootstrap_user="$2"
    local pub_key="$3"
    
    print_info "Checking if SSH key already exists..."
    
    # Extract just the key part (without comment)
    local key_part=$(echo "$pub_key" | awk '{print $1 " " $2}')
    
    if ssh "$bootstrap_user@$server_ip" \
        "sudo grep -qF '$key_part' /home/$ANSIBLE_USER/.ssh/authorized_keys" 2>/dev/null; then
        return 0  # Key exists
    else
        return 1  # Key doesn't exist
    fi
}

# Copy SSH key to ansible user
copy_ssh_key() {
    local server_ip="$1"
    local bootstrap_user="$2"
    
    local pub_key=$(cat "${ANSIBLE_KEY}.pub")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would copy SSH public key to ansible@$server_ip"
        return 0
    fi
    
    # Check if key already exists
    if check_existing_key "$server_ip" "$bootstrap_user" "$pub_key"; then
        print_info "SSH key already present in authorized_keys"
        print_success "No need to add duplicate key"
        return 0
    fi
    
    print_info "Copying SSH public key to ansible@$server_ip..."
    
    if ssh "$bootstrap_user@$server_ip" \
        "echo '$pub_key' | sudo tee -a /home/$ANSIBLE_USER/.ssh/authorized_keys > /dev/null && \
         sudo chmod 600 /home/$ANSIBLE_USER/.ssh/authorized_keys && \
         sudo chown $ANSIBLE_USER:$ANSIBLE_USER /home/$ANSIBLE_USER/.ssh/authorized_keys" 2>/dev/null; then
        print_success "SSH key copied successfully"
        return 0
    else
        print_error "Failed to copy SSH key"
        return 1
    fi
}

# Test ansible user access
test_ansible_access() {
    local server_ip="$1"
    
    print_info "Testing SSH access as ansible user..."
    
    if ssh -i "$ANSIBLE_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "$ANSIBLE_USER@$server_ip" "whoami" &>/dev/null; then
        print_success "Ansible user SSH access: OK"
    else
        print_error "Ansible user SSH access: FAILED"
        print_info "Debug with: ssh -v -i $ANSIBLE_KEY $ANSIBLE_USER@$server_ip"
        return 1
    fi
    
    print_info "Testing passwordless sudo..."
    
    if ssh -i "$ANSIBLE_KEY" "$ANSIBLE_USER@$server_ip" "sudo whoami" 2>/dev/null | grep -q "root"; then
        print_success "Passwordless sudo: OK"
        return 0
    else
        print_error "Passwordless sudo: FAILED"
        print_info "Check: /etc/sudoers.d/$ANSIBLE_USER on target server"
        return 1
    fi
}

# Get server hostname
get_server_hostname() {
    local server_ip="$1"
    local provided_hostname="$2"
    
    if [[ -n "$provided_hostname" ]]; then
        print_info "Using provided hostname: $provided_hostname"
        echo "$provided_hostname"
        return 0
    fi
    
    print_info "Detecting hostname from server..."
    
    local detected_hostname=$(ssh -i "$ANSIBLE_KEY" "$ANSIBLE_USER@$server_ip" "hostname" 2>/dev/null || echo "")
    
    if [[ -n "$detected_hostname" ]]; then
        print_success "Detected hostname: $detected_hostname"
        echo "$detected_hostname"
    else
        print_warning "Could not detect hostname, using IP address"
        echo "$server_ip"
    fi
}

# Add to Ansible inventory
add_to_inventory() {
    local server_ip="$1"
    local hostname="$2"
    
    # Detect inventory file if not specified
    if [[ ! -f "$INVENTORY_FILE" ]] && [[ "$INVENTORY_FILE" == "/etc/ansible/hosts" ]]; then
        local detected=$(detect_inventory_file)
        if [[ "$detected" != "$INVENTORY_FILE" ]]; then
            print_info "Using detected inventory: $detected"
            INVENTORY_FILE="$detected"
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would add to inventory: $INVENTORY_FILE"
        print_info "[DRY RUN] Entry: $server_ip   # $hostname"
        return 0
    fi
    
    # Check if server already in inventory
    if [[ -f "$INVENTORY_FILE" ]] && grep -q "^$server_ip" "$INVENTORY_FILE" 2>/dev/null; then
        print_info "Server already in inventory: $INVENTORY_FILE"
        return 0
    fi
    
    print_info "Adding to inventory: $INVENTORY_FILE"
    
    local inventory_entry="$server_ip   # $hostname - Added $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Try to add to inventory
    if [[ -w "$INVENTORY_FILE" ]]; then
        # Writable, add directly
        echo "$inventory_entry" >> "$INVENTORY_FILE"
        ADDED_TO_INVENTORY=true
        SERVER_IP_GLOBAL="$server_ip"
        print_success "Added to Ansible inventory"
    elif sudo test -w "$INVENTORY_FILE" 2>/dev/null; then
        # Need sudo
        echo "$inventory_entry" | sudo tee -a "$INVENTORY_FILE" > /dev/null
        ADDED_TO_INVENTORY=true
        SERVER_IP_GLOBAL="$server_ip"
        print_success "Added to Ansible inventory (with sudo)"
    else
        print_warning "Could not add to inventory automatically"
        print_info "Please add manually to $INVENTORY_FILE:"
        echo "  $inventory_entry"
        return 1
    fi
    
    return 0
}

# Test Ansible connectivity
test_ansible_connectivity() {
    local server_ip="$1"
    local hostname="$2"
    
    print_info "Running Ansible ping test..."
    
    # Build ansible command
    local ansible_cmd="ansible"
    local ansible_opts="-m ping --user $ANSIBLE_USER --private-key $ANSIBLE_KEY"
    
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -vvv"
    fi
    
    # Try using inventory entry (by IP)
    if $ansible_cmd "$server_ip" $ansible_opts 2>&1 | grep -q "SUCCESS"; then
        print_success "Ansible connectivity: SUCCESS (via IP)"
        return 0
    # Try using comma syntax (ad-hoc inventory)
    elif $ansible_cmd "${server_ip}," $ansible_opts 2>&1 | grep -q "SUCCESS"; then
        print_success "Ansible connectivity: SUCCESS (ad-hoc)"
        return 0
    else
        print_warning "Ansible ping test failed"
        print_info "This may be normal if ansible.cfg needs configuration"
        print_info "Test manually with: ansible $server_ip -m ping --user $ANSIBLE_USER"
        return 1
    fi
}

# Show final summary
show_summary() {
    local server_ip="$1"
    local hostname="$2"
    
    echo ""
    print_header "Finalization Complete!"
    
    print_success "Server $server_ip is now ready for Ansible management"
    echo ""
    echo -e "${BOLD}Server Details:${NC}"
    echo "  IP Address:    $server_ip"
    echo "  Hostname:      $hostname"
    echo "  Ansible User:  $ANSIBLE_USER (SSH key authentication)"
    echo "  SSH Key:       $ANSIBLE_KEY"
    echo "  Inventory:     $INVENTORY_FILE"
    echo ""
    echo -e "${BOLD}You can now manage this server:${NC}"
    echo "  ${CYAN}# Test connectivity${NC}"
    echo "  ${CYAN}ansible $server_ip -m ping${NC}"
    if [[ "$hostname" != "$server_ip" ]] && [[ "$hostname" != "unknown" ]]; then
        echo "  ${CYAN}ansible $hostname -m ping${NC}"
    fi
    echo ""
    echo "  ${CYAN}# Get system info${NC}"
    echo "  ${CYAN}ansible $server_ip -m setup${NC}"
    echo ""
    echo "  ${CYAN}# Run commands${NC}"
    echo "  ${CYAN}ansible $server_ip -a 'uptime'${NC}"
    echo "  ${CYAN}ansible $server_ip -a 'df -h'${NC}"
    echo ""
    echo -e "${BOLD}Log file saved to:${NC} $LOG_FILE"
    echo ""
}

# Main script
main() {
    # Enable verbose mode if requested
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Start logging
    log "=== Ansible Server Finalization Started ==="
    log "Version: $SCRIPT_VERSION"
    log "Timestamp: $(date)"
    
    # Show banner
    clear
    print_header "Ansible Server Finalization v${SCRIPT_VERSION}"
    
    # Parse arguments
    SERVER_IP="${1:-}"
    BOOTSTRAP_USER="${2:-}"
    HOSTNAME="${3:-}"
    
    # Check for help
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Check SSH key exists
    if ! check_ssh_key; then
        exit 1
    fi
    
    # Get server details
    IFS='|' read -r SERVER_IP BOOTSTRAP_USER HOSTNAME <<< "$(get_server_details "$SERVER_IP" "$BOOTSTRAP_USER" "$HOSTNAME")"
    
    # Display configuration
    echo ""
    print_header "Configuration Summary"
    echo -e "${BOLD}Target Server:${NC}"
    echo "  IP Address:       $SERVER_IP"
    echo "  Bootstrap User:   $BOOTSTRAP_USER"
    echo "  Ansible User:     $ANSIBLE_USER"
    echo "  SSH Key:          ${ANSIBLE_KEY}"
    echo "  Inventory File:   $INVENTORY_FILE"
    echo "  Dry Run:          $DRY_RUN"
    echo "  Verbose:          $VERBOSE"
    echo "  Log File:         $LOG_FILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    echo ""
    read -p "Continue with this configuration? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Cancelled by user"
        log "=== Cancelled by user ==="
        exit 0
    fi
    
    # Run checks and setup
    print_header "Step 1: Connectivity Check"
    log "Step 1: Testing connectivity"
    
    if ! test_connectivity "$SERVER_IP" "$BOOTSTRAP_USER"; then
        log "ERROR: Connectivity check failed"
        exit 1
    fi
    
    echo ""
    print_header "Step 2: Verify Ansible User Exists"
    log "Step 2: Checking ansible user"
    
    if ! check_ansible_user_exists "$SERVER_IP" "$BOOTSTRAP_USER"; then
        log "ERROR: Ansible user check failed"
        exit 1
    fi
    
    echo ""
    print_header "Step 3: Copy SSH Key to Ansible User"
    log "Step 3: Copying SSH key"
    
    if ! copy_ssh_key "$SERVER_IP" "$BOOTSTRAP_USER"; then
        log "ERROR: SSH key copy failed"
        exit 1
    fi
    
    echo ""
    print_header "Step 4: Test Ansible User Access"
    log "Step 4: Testing ansible access"
    
    if ! test_ansible_access "$SERVER_IP"; then
        log "ERROR: Ansible access test failed"
        exit 1
    fi
    
    echo ""
    print_header "Step 5: Get Server Hostname"
    log "Step 5: Getting hostname"
    
    HOSTNAME=$(get_server_hostname "$SERVER_IP" "$HOSTNAME")
    log "Hostname: $HOSTNAME"
    
    echo ""
    print_header "Step 6: Add to Ansible Inventory"
    log "Step 6: Adding to inventory"
    
    if ! add_to_inventory "$SERVER_IP" "$HOSTNAME"; then
        print_warning "Could not add to inventory automatically"
        # Not a fatal error - continue
    fi
    
    echo ""
    print_header "Step 7: Test Ansible Connectivity"
    log "Step 7: Testing Ansible"
    
    if ! test_ansible_connectivity "$SERVER_IP" "$HOSTNAME"; then
        print_warning "Ansible test had issues (may be configuration related)"
        # Not a fatal error
    fi
    
    # Show final summary
    show_summary "$SERVER_IP" "$HOSTNAME"
    
    log "=== Finalization Completed Successfully ==="
    log "Server: $SERVER_IP ($HOSTNAME)"
}

# Run main function
main "$@"