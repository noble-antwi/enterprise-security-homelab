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
SCRIPT_VERSION="1.5.1"

# Detect actual user (even if run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    # Script was run with sudo, use the original user
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    # Script run normally
    ACTUAL_USER="${USER:-$(whoami)}"
    ACTUAL_HOME="${HOME}"
fi

# Configuration with fallbacks
if [[ -n "${ANSIBLE_USER:-}" ]]; then
    ANSIBLE_USER_SET="true"
else
    ANSIBLE_USER="ansible"  # Default, will be updated by detection
fi

ANSIBLE_KEY="${ANSIBLE_SSH_KEY:-${ACTUAL_HOME}/.ssh/ansible-automation-key}"
INVENTORY_FILE="${ANSIBLE_INVENTORY:-/etc/ansible/hosts}"

# Check if DRY_RUN or VERBOSE were set via environment
if [[ -n "${DRY_RUN:-}" ]]; then
    DRY_RUN_SET="true"
else
    DRY_RUN="false"
fi

if [[ -n "${VERBOSE:-}" ]]; then
    VERBOSE_SET="true"
else
    VERBOSE="false"
fi

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

${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}
${BOLD}${CYAN}                 UNDERSTANDING THE TWO SCRIPTS${NC}
${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}

${BOLD}There are TWO scripts with DIFFERENT purposes:${NC}

${BOLD}1. server-bootstrap.sh${NC} ${YELLOW}(Run on TARGET server)${NC}
   Location:  Target server (lab-devops-svc01, grafana, etc.)
   User:      Run WITH sudo
   Command:   ${CYAN}sudo ./server-bootstrap.sh${NC}
   Purpose:   Creates ansible user, sets up system
   
${BOLD}2. ansible-finalize-server.sh${NC} ${YELLOW}(Run on CONTROLLER)${NC}
   Location:  Ansible controller (ansible-mgmt-01)
   User:      Run WITHOUT sudo (as svc-ansible)
   Command:   ${CYAN}./ansible-finalize-server.sh${NC} ${RED}(no sudo!)${NC}
   Purpose:   Copies SSH keys, adds to inventory

${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}

${BOLD}PURPOSE:${NC}
    Complete Ansible integration after running server-bootstrap.sh on target server.
    This script copies SSH keys, tests connectivity, and adds server to inventory.

${BOLD}${RED}⚠️  CRITICAL: DO NOT RUN WITH SUDO!${NC}
    
    ${RED}✗ Wrong:${NC}  sudo ./ansible-finalize-server.sh
    ${GREEN}✓ Right:${NC} ./ansible-finalize-server.sh
    
    ${BOLD}Why no sudo?${NC}
    • server-bootstrap.sh needs sudo (creates system users)
    • This script does NOT need sudo (copies SSH keys)
    • Using sudo causes "SSH key not found" errors
    • Script handles sudo internally when needed

${BOLD}PREREQUISITES:${NC}
    1. server-bootstrap.sh has been run on target server (with sudo)
    2. 'ansible' user exists on target server
    3. You can SSH to target server with your username
    4. Ansible is installed on this controller
    5. Running on ansible-mgmt-01 as svc-ansible user

${BOLD}WORKFLOW SUMMARY:${NC}
    Step 1: On target server (192.168.40.2):
            ${CYAN}sudo ./server-bootstrap.sh${NC}
            
    Step 2: On controller (192.168.10.2):
            ${CYAN}./ansible-finalize-server.sh 192.168.40.2 nantwi${NC}
            
    Step 3: Test:
            ${CYAN}ansible 192.168.40.2 -m ping${NC}

${BOLD}WHAT THIS SCRIPT DOES:${NC}
    Runs FROM: ansible-mgmt-01 (this controller)
    Connects TO: Target server (lab-devops-svc01, grafana, etc.)
    Result: Ansible can manage the target server

${BOLD}USAGE:${NC}
    Interactive mode (recommended):
        $0

    Non-interactive mode:
        $0 <target_server_ip> <your_username> [hostname]

    Dry-run mode:
        DRY_RUN=true $0 192.168.40.2 nantwi

    Verbose mode:
        VERBOSE=true $0 192.168.40.2 nantwi

${BOLD}EXAMPLES:${NC}
    # Interactive - prompts for all information
    $0

    # Add lab-devops-svc01 to Ansible management
    $0 192.168.40.2 nantwi lab-devops-svc01

    # Add grafana server
    $0 192.168.60.2 nantwi grafana-server

    # Test without making changes
    DRY_RUN=true $0 192.168.40.2 nantwi

${BOLD}WHAT YOU'LL BE ASKED:${NC}
    1. ${BOLD}Target Server IP:${NC} IP of the REMOTE server to manage
       Example: 192.168.40.2 (lab-devops-svc01)
       ${RED}NOT the controller IP (192.168.10.2)${NC}
    
    2. ${BOLD}Bootstrap Username:${NC} YOUR username on that server
       Example: nantwi, vagrant, ubuntu
       ${RED}NOT 'ansible' (that's what we're setting up)${NC}
    
    3. ${BOLD}Hostname:${NC} Optional - will auto-detect if not provided

${BOLD}ENVIRONMENT VARIABLES:${NC}
    ANSIBLE_SSH_KEY      SSH private key path
                         Default: ~/.ssh/ansible-automation-key
    ANSIBLE_USER         Ansible username (default: ansible)
    ANSIBLE_INVENTORY    Inventory path (default: /etc/ansible/hosts)
    DRY_RUN              Test mode (default: false)
    VERBOSE              Debug mode (default: false)

${BOLD}LOG FILE:${NC}
    All operations logged to: $LOG_FILE

EOF
}

# Smart Ansible user detection
detect_ansible_user() {
    print_info "Detecting Ansible automation user..."
    
    # Check if already set via environment variable
    if [[ -n "${ANSIBLE_USER_SET:-}" ]]; then
        print_info "Using ANSIBLE_USER from environment: $ANSIBLE_USER"
        return 0
    fi
    
    # Try default 'ansible' user first
    if id "ansible" &>/dev/null 2>&1; then
        ANSIBLE_USER="ansible"
        print_success "Found default 'ansible' user"
        return 0
    fi
    
    print_info "Default 'ansible' user not found"
    print_info "Searching for Ansible-related users on this controller..."
    
    # Search for potential Ansible users
    local candidates=()
    local candidate_info=()
    
    while IFS=: read -r username _ uid _ _ home _; do
        # Skip system users (uid < 1000)
        if [[ "$uid" -lt 1000 ]]; then
            continue
        fi
        
        # Look for ansible-related usernames
        if [[ "$username" =~ ansible ]] || \
           [[ "$username" =~ automation ]] || \
           [[ "$username" == svc_* && "$username" =~ ansible ]]; then
            candidates+=("$username")
            candidate_info+=("$username (uid: $uid, home: $home)")
        fi
    done < /etc/passwd
    
    # Handle results
    if [[ ${#candidates[@]} -eq 0 ]]; then
        # No candidates found
        echo ""
        print_warning "No Ansible-related users found on this controller"
        echo ""
        echo -e "${BOLD}What would you like to do?${NC}"
        echo "  1. Create new 'ansible' user (recommended for standard setup)"
        echo "  2. Enter existing username (if using custom naming)"
        echo "  3. Exit and create user manually"
        echo ""
        read -p "Choose option (1-3): " -n 1 -r choice
        echo ""
        
        case "$choice" in
            1)
                offer_to_create_ansible_user
                ;;
            2)
                prompt_manual_ansible_user
                ;;
            3)
                print_warning "Exiting - please create Ansible user first"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
        
    elif [[ ${#candidates[@]} -eq 1 ]]; then
        # One candidate found - confirm with user
        echo ""
        print_success "Found potential Ansible user: ${GREEN}${candidates[0]}${NC}"
        echo ""
        echo -e "${BOLD}User details:${NC}"
        echo "  ${candidate_info[0]}"
        echo ""
        read -p "Is '${candidates[0]}' your Ansible automation user? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ANSIBLE_USER="${candidates[0]}"
            print_success "Using '${ANSIBLE_USER}' as Ansible automation user"
            return 0
        else
            echo ""
            print_info "Let's find the correct user"
            prompt_manual_ansible_user
        fi
        
    else
        # Multiple candidates found - let user choose
        echo ""
        print_success "Found ${#candidates[@]} potential Ansible users:"
        echo ""
        
        for i in "${!candidates[@]}"; do
            echo "  $((i+1)). ${candidate_info[$i]}"
        done
        echo "  $((${#candidates[@]}+1)). Enter different username"
        echo "  $((${#candidates[@]}+2)). Create new 'ansible' user"
        echo ""
        
        read -p "Select option (1-$((${#candidates[@]}+2))): " choice
        echo ""
        
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [[ "$choice" -ge 1 && "$choice" -le ${#candidates[@]} ]]; then
                ANSIBLE_USER="${candidates[$((choice-1))]}"
                print_success "Using '${ANSIBLE_USER}' as Ansible automation user"
                return 0
            elif [[ "$choice" -eq $((${#candidates[@]}+1)) ]]; then
                prompt_manual_ansible_user
            elif [[ "$choice" -eq $((${#candidates[@]}+2)) ]]; then
                offer_to_create_ansible_user
            else
                print_error "Invalid selection"
                exit 1
            fi
        else
            print_error "Invalid input"
            exit 1
        fi
    fi
}

# Prompt for manual Ansible username entry
prompt_manual_ansible_user() {
    echo ""
    echo -e "${BOLD}Enter your Ansible automation username:${NC}"
    echo ""
    echo "Common names:"
    echo "  • ansible"
    echo "  • svc_ansible"
    echo "  • ansible-automation"
    echo "  • automation"
    echo ""
    read -p "Automation username: " manual_user
    
    if [[ -z "$manual_user" ]]; then
        print_error "Username cannot be empty"
        exit 1
    fi
    
    # Validate user exists
    if id "$manual_user" &>/dev/null 2>&1; then
        ANSIBLE_USER="$manual_user"
        print_success "Using '${ANSIBLE_USER}' as Ansible automation user"
        return 0
    else
        print_error "User '$manual_user' does not exist on this system"
        echo ""
        read -p "Would you like to create this user? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ANSIBLE_USER="$manual_user"
            offer_to_create_ansible_user
        else
            exit 1
        fi
    fi
}

# Offer to create ansible user on controller
offer_to_create_ansible_user() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  CREATE ANSIBLE USER ON CONTROLLER${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}This is a ONE-TIME setup for the Ansible CONTROLLER.${NC}"
    echo ""
    echo -e "${YELLOW}Important distinction:${NC}"
    echo "  • ${GREEN}Controller setup${NC} (this): Creates automation user on THIS machine"
    echo "  • ${GREEN}Target setup${NC} (different): Uses server-bootstrap.sh on REMOTE servers"
    echo ""
    echo -e "${BOLD}What will be created:${NC}"
    echo "  • User: ${ANSIBLE_USER}"
    echo "  • Home: /home/${ANSIBLE_USER}"
    echo "  • SSH directory: /home/${ANSIBLE_USER}/.ssh"
    echo "  • Passwordless sudo: Enabled"
    echo ""
    
    read -p "Create '${ANSIBLE_USER}' user on this controller now? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        print_warning "Cancelled - you can create the user manually:"
        echo ""
        echo "  ${CYAN}sudo useradd -m -s /bin/bash ${ANSIBLE_USER}${NC}"
        echo "  ${CYAN}sudo mkdir -p /home/${ANSIBLE_USER}/.ssh${NC}"
        echo "  ${CYAN}sudo chmod 700 /home/${ANSIBLE_USER}/.ssh${NC}"
        echo "  ${CYAN}sudo chown ${ANSIBLE_USER}:${ANSIBLE_USER} /home/${ANSIBLE_USER}/.ssh${NC}"
        echo "  ${CYAN}echo '${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${ANSIBLE_USER}${NC}"
        echo "  ${CYAN}sudo chmod 440 /etc/sudoers.d/${ANSIBLE_USER}${NC}"
        echo ""
        exit 0
    fi
    
    echo ""
    print_info "Creating '${ANSIBLE_USER}' user on controller..."
    
    # Create user
    if sudo useradd -m -s /bin/bash "${ANSIBLE_USER}" 2>/dev/null; then
        print_success "User '${ANSIBLE_USER}' created"
    else
        print_error "Failed to create user"
        exit 1
    fi
    
    # Create SSH directory
    if sudo mkdir -p "/home/${ANSIBLE_USER}/.ssh" && \
       sudo chmod 700 "/home/${ANSIBLE_USER}/.ssh" && \
       sudo chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "/home/${ANSIBLE_USER}/.ssh"; then
        print_success "SSH directory created"
    else
        print_warning "Failed to create SSH directory"
    fi
    
    # Set up passwordless sudo
    if echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/${ANSIBLE_USER}" > /dev/null && \
       sudo chmod 440 "/etc/sudoers.d/${ANSIBLE_USER}"; then
        print_success "Passwordless sudo configured"
    else
        print_warning "Failed to configure sudo"
    fi
    
    echo ""
    print_success "User '${ANSIBLE_USER}' is ready!"
    echo ""
}
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
    local warnings=()
    
    # Check if ansible is installed
    if ! command -v ansible &>/dev/null; then
        missing+=("ansible")
        warnings+=("Ansible is not installed on this system")
        warnings+=("This script should run on the Ansible controller")
        warnings+=("Install with: sudo apt install ansible")
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
        echo ""
        
        # Show specific warnings
        for warning in "${warnings[@]}"; do
            print_warning "$warning"
        done
        
        echo ""
        print_info "Common causes:"
        echo "  • Running on wrong machine (should be ansible-mgmt-01)"
        echo "  • Ansible not installed yet"
        echo "  • Running on target server instead of controller"
        echo ""
        
        return 1
    fi
    
    print_success "All prerequisites installed"
    
    # Additional checks for better UX
    local hostname=$(hostname)
    if [[ "$hostname" != "ansible-mgmt-01" ]]; then
        print_warning "Current hostname: $hostname (expected: ansible-mgmt-01)"
        print_info "Make sure you're running this on the Ansible controller"
    else
        print_success "Running on Ansible controller (ansible-mgmt-01)"
    fi
    
    return 0
}

# Check if SSH key exists
check_ssh_key() {
    print_info "Checking SSH key: ${ANSIBLE_KEY}"
    print_info "Running as user: $ACTUAL_USER (home: $ACTUAL_HOME)"
    
    if [[ ! -f "${ANSIBLE_KEY}" ]]; then
        print_error "SSH private key not found: ${ANSIBLE_KEY}"
        echo ""
        print_warning "Common issues:"
        echo "  1. Key is in different location"
        echo "  2. Script run with sudo (changes HOME to /root)"
        echo ""
        print_info "Your SSH keys should be in: ${ACTUAL_HOME}/.ssh/"
        
        # Check if keys exist elsewhere
        if [[ -f "${ACTUAL_HOME}/.ssh/ansible-automation-key" ]]; then
            print_success "Found key at: ${ACTUAL_HOME}/.ssh/ansible-automation-key"
            print_info "This is the correct location!"
        else
            print_info "Key not found in ${ACTUAL_HOME}/.ssh/ either"
            echo ""
            print_info "Please generate SSH keys first:"
            echo "  ssh-keygen -t ed25519 -f ${ACTUAL_HOME}/.ssh/ansible-automation-key -C 'ansible-automation'"
            echo ""
            print_info "Or if keys exist elsewhere, set environment variable:"
            echo "  ANSIBLE_SSH_KEY=/path/to/your/key $0"
        fi
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
    print_success "SSH public key exists: ${ANSIBLE_KEY}.pub"
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
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}  TARGET SERVER TO MANAGE${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "This script runs FROM ansible-mgmt-01 (this controller)"
        print_info "It connects TO a remote server to set up Ansible management"
        echo ""
        echo -e "${BOLD}Enter the IP address of the REMOTE server you want to manage:${NC}"
        echo ""
        print_warning "Examples of remote servers:"
        echo "  • lab-devops-svc01:  192.168.40.2"
        echo "  • grafana-server:    192.168.60.2"
        echo "  • wazuh-siem:        192.168.20.2"
        echo "  • tcm-ubuntu:        192.168.10.4"
        echo ""
        echo -e "${BOLD}${RED}NOT this controller (192.168.10.2)${NC}"
        echo ""
        
        while true; do
            read -p "Target server IP address: " server_ip
            
            if [[ -z "$server_ip" ]]; then
                print_error "Server IP is required"
                continue
            fi
            
            # Warn if they entered the controller IP
            if [[ "$server_ip" == "192.168.10.2" ]]; then
                print_warning "That's THIS controller (ansible-mgmt-01)"
                print_warning "Enter the IP of the REMOTE server you want to manage"
                echo ""
                read -p "Continue with 192.168.10.2 anyway? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    continue
                fi
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
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}  YOUR USERNAME ON TARGET SERVER${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "The script needs to SSH to the target server"
        print_info "Enter the username YOU use to login to that server"
        echo ""
        echo -e "${BOLD}What is this?${NC}"
        echo "  • This is YOUR personal account on the target server"
        echo "  • The account you can SSH with RIGHT NOW"
        echo "  • Used to copy keys to the ansible automation account"
        echo ""
        print_warning "Common usernames:"
        echo "  • nantwi        (your personal username)"
        echo "  • vagrant       (if using Vagrant VMs)"
        echo "  • ubuntu        (default on Ubuntu cloud images)"
        echo "  • your-name     (whatever you created)"
        echo ""
        echo -e "${BOLD}${RED}NOT 'ansible' - that's the automation account we're setting up!${NC}"
        echo ""
        echo -e "${BOLD}Example:${NC}"
        echo "  If you normally SSH with: ${CYAN}ssh nantwi@$server_ip${NC}"
        echo "  Then enter: ${GREEN}nantwi${NC}"
        echo ""
        read -p "Your username on target server: " bootstrap_user
        
        if [[ -z "$bootstrap_user" ]]; then
            print_error "Username is required"
            exit 1
        fi
        
        # Warn if they entered 'ansible'
        if [[ "$bootstrap_user" == "ansible" ]]; then
            echo ""
            print_error "'ansible' is the automation account (not set up yet!)"
            print_error "You need a personal account that can SSH to the server"
            echo ""
            echo -e "${BOLD}If you don't have a personal account on the target:${NC}"
            echo "  1. SSH to target as root or another user"
            echo "  2. Create your personal account"
            echo "  3. Then run this script"
            echo ""
            exit 1
        fi
        
        # Warn if they entered 'root'
        if [[ "$bootstrap_user" == "root" ]]; then
            print_warning "Using 'root' is not recommended for security"
            print_info "Consider creating a personal account instead"
            echo ""
            read -p "Continue with root? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
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
    
    # Check if /etc/ansible directory exists
    if [[ ! -d "/etc/ansible" ]]; then
        print_warning "/etc/ansible directory does not exist"
        print_info "Creating /etc/ansible directory..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "[DRY RUN] Would create /etc/ansible directory"
        else
            if sudo mkdir -p /etc/ansible 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Created /etc/ansible directory"
                
                # Set ownership to actual user
                if sudo chown "$ACTUAL_USER:$ACTUAL_USER" /etc/ansible 2>&1 | tee -a "$LOG_FILE"; then
                    print_success "Set ownership to $ACTUAL_USER"
                fi
            else
                print_error "Failed to create /etc/ansible directory"
                print_info "You may need to create it manually: sudo mkdir -p /etc/ansible"
                return 1
            fi
        fi
    fi
    
    # Check if inventory file exists
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_info "Inventory file does not exist: $INVENTORY_FILE"
        print_info "Creating inventory file..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "[DRY RUN] Would create inventory file"
        else
            # Create inventory file with header
            sudo tee "$INVENTORY_FILE" > /dev/null << EOF
# Ansible Inventory File
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Format: IP_ADDRESS   # HOSTNAME - DESCRIPTION

EOF
            sudo chown "$ACTUAL_USER:$ACTUAL_USER" "$INVENTORY_FILE"
            sudo chmod 644 "$INVENTORY_FILE"
            print_success "Created inventory file: $INVENTORY_FILE"
        fi
    fi
    
    # Detect inventory file if not specified or doesn't exist
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
    
    # ============================================================================
    # CRITICAL: Detect and explain sudo/root execution context
    # ============================================================================
    
    # Check if run with sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo ""
        echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║                                                                           ║${NC}"
        echo -e "${BOLD}${RED}║                           ⚠️  STOP! READ THIS ⚠️                          ║${NC}"
        echo -e "${BOLD}${RED}║                                                                           ║${NC}"
        echo -e "${BOLD}${RED}║                   THIS SCRIPT WAS RUN WITH SUDO                           ║${NC}"
        echo -e "${BOLD}${RED}║                                                                           ║${NC}"
        echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}${YELLOW}I understand the confusion!${NC}"
        echo ""
        echo -e "${BOLD}You probably ran this with sudo because:${NC}"
        echo "  • You used 'sudo ./server-bootstrap.sh' on the remote server"
        echo "  • So you thought this script also needs sudo"
        echo ""
        echo -e "${BOLD}${GREEN}But these are DIFFERENT scripts with DIFFERENT purposes:${NC}"
        echo ""
        echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}│ server-bootstrap.sh (on REMOTE server)                          │${NC}"
        echo -e "${BOLD}├─────────────────────────────────────────────────────────────────┤${NC}"
        echo "  ${GREEN}✓${NC} Runs on the TARGET server (lab-devops-svc01)"
        echo "  ${GREEN}✓${NC} NEEDS sudo - creates system users, modifies /etc/"
        echo "  ${GREEN}✓${NC} Creates ansible user, sets up sudoers"
        echo "  ${GREEN}✓${NC} Usage: ${CYAN}sudo ./server-bootstrap.sh${NC}"
        echo -e "${BOLD}└─────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}│ ansible-finalize-server.sh (on CONTROLLER)                      │${NC}"
        echo -e "${BOLD}├─────────────────────────────────────────────────────────────────┤${NC}"
        echo "  ${GREEN}✓${NC} Runs on THIS controller (ansible-mgmt-01)"
        echo "  ${RED}✗${NC} Does NOT need sudo - just SSH key operations"
        echo "  ${GREEN}✓${NC} Copies your SSH keys, adds to inventory"
        echo "  ${GREEN}✓${NC} Usage: ${CYAN}./ansible-finalize-server.sh${NC} ${RED}(no sudo!)${NC}"
        echo -e "${BOLD}└─────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${BOLD}${YELLOW}What happens when you use sudo here:${NC}"
        echo "  ${RED}✗${NC} Script looks for keys in /root/.ssh/ instead of /home/$SUDO_USER/.ssh/"
        echo "  ${RED}✗${NC} Can't find your SSH keys"
        echo "  ${RED}✗${NC} Fails with 'SSH key not found' error"
        echo ""
        echo -e "${BOLD}${GREEN}What you should do:${NC}"
        echo "  1. Press Ctrl+C to exit this script"
        echo "  2. Run again WITHOUT sudo:"
        echo ""
        echo -e "     ${CYAN}./ansible-finalize-server-v1.2.sh${NC}"
        echo ""
        echo "  3. The script will handle sudo internally when needed (for /etc/ansible)"
        echo ""
        
        log "WARNING: Script run with sudo (user: $SUDO_USER)"
        
        read -p "Do you want to continue anyway? (not recommended) (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            print_success "Good choice! Please run without sudo:"
            echo ""
            echo -e "  ${CYAN}./ansible-finalize-server-v1.2.sh${NC}"
            echo ""
            log "=== User chose to exit after sudo warning ==="
            exit 0
        fi
        echo ""
        print_warning "Continuing with sudo... (will try to use $SUDO_USER's settings)"
        echo ""
    fi
    
    # Check if running as root directly
    if [[ "$ACTUAL_USER" == "root" ]]; then
        echo ""
        echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║                                                                           ║${NC}"
        echo -e "${BOLD}${RED}║                          ⚠️  RUNNING AS ROOT ⚠️                          ║${NC}"
        echo -e "${BOLD}${RED}║                                                                           ║${NC}"
        echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        print_warning "You are logged in as the root user"
        print_warning "This script should be run as a regular user (svc-ansible)"
        echo ""
        echo -e "${BOLD}Why run as regular user?${NC}"
        echo "  • SSH keys are in /home/svc-ansible/.ssh/"
        echo "  • Ansible configuration is for svc-ansible user"
        echo "  • Better security practice"
        echo ""
        echo -e "${BOLD}What to do:${NC}"
        echo "  1. Switch to svc-ansible user: ${CYAN}su - svc-ansible${NC}"
        echo "  2. Run this script from there"
        echo ""
        
        log "WARNING: Script run as root user"
        
        read -p "Continue as root anyway? (not recommended) (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cancelled - please run as svc-ansible user"
            log "=== User chose to exit when running as root ==="
            exit 0
        fi
        echo ""
    fi
    
    # Show detected user context
    echo ""
    print_header "Execution Context"
    print_info "Running on: $(hostname)"
    print_info "Running as: $ACTUAL_USER"
    print_info "Home directory: $ACTUAL_HOME"
    
    # Warn if not running on expected controller
    local current_hostname=$(hostname)
    if [[ "$current_hostname" != "ansible-mgmt-01" ]]; then
        echo ""
        print_warning "This doesn't appear to be the Ansible controller"
        print_info "Detected hostname: $current_hostname"
        print_info "Expected hostname: ansible-mgmt-01"
        echo ""
        echo -e "${BOLD}Are you sure you want to run this script here?${NC}"
        echo ""
        echo "This script should run:"
        echo "  ${GREEN}✓${NC} FROM: ansible-mgmt-01 (the controller)"
        echo "  ${GREEN}✓${NC} TO: Target servers (lab-devops-svc01, etc.)"
        echo ""
        
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    echo ""
    
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
    
    echo ""
    print_header "Validating Your Setup"
    
    # Check if the user running this script has proper setup
    print_info "Checking if $ACTUAL_USER is ready to manage Ansible..."
    
    # Check 1: SSH key exists
    if ! check_ssh_key; then
        echo ""
        print_error "Your user ($ACTUAL_USER) is not set up properly for Ansible management"
        echo ""
        echo -e "${BOLD}What you need:${NC}"
        echo "  1. SSH keys for Ansible automation"
        echo "  2. Proper SSH key setup"
        echo ""
        echo -e "${BOLD}Generate SSH keys:${NC}"
        echo "  ssh-keygen -t ed25519 -f ${ACTUAL_HOME}/.ssh/ansible-automation-key -C 'ansible-automation'"
        echo ""
        exit 1
    fi
    
    # Check 2: Detect or validate Ansible automation user
    echo ""
    detect_ansible_user
    
    # Validate the detected/selected user
    if ! id "$ANSIBLE_USER" &>/dev/null; then
        print_error "Selected user '$ANSIBLE_USER' does not exist"
        exit 1
    fi
    
    print_success "Ansible automation user: '$ANSIBLE_USER'"
    
    # Check if ansible user has proper setup
    if [[ -d "/home/$ANSIBLE_USER/.ssh" ]]; then
        print_success "Ansible user has SSH directory"
    else
        print_info "Ansible user missing .ssh directory (will be created on target)"
    fi
    
    # Get server details
    if [[ -z "$SERVER_IP" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}  TARGET SERVER TO MANAGE${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "This script runs FROM ansible-mgmt-01 (this controller)"
        print_info "It connects TO a remote server to set up Ansible management"
        echo ""
        echo -e "${BOLD}Enter the IP address of the REMOTE server you want to manage:${NC}"
        echo ""
        print_warning "Examples of remote servers:"
        echo "  • lab-devops-svc01:  192.168.40.2"
        echo "  • grafana-server:    192.168.60.2"
        echo "  • wazuh-siem:        192.168.20.2"
        echo "  • tcm-ubuntu:        192.168.10.4"
        echo ""
        echo -e "${BOLD}${RED}NOT this controller (192.168.10.2)${NC}"
        echo ""
        
        while true; do
            read -p "Target server IP address: " SERVER_IP
            
            if [[ -z "$SERVER_IP" ]]; then
                print_error "Server IP is required"
                continue
            fi
            
            # Warn if they entered the controller IP
            if [[ "$SERVER_IP" == "192.168.10.2" ]]; then
                print_warning "That's THIS controller (ansible-mgmt-01)"
                print_warning "Enter the IP of the REMOTE server you want to manage"
                echo ""
                read -p "Continue with 192.168.10.2 anyway? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            if validate_ip "$SERVER_IP"; then
                break
            fi
        done
    else
        if ! validate_ip "$SERVER_IP"; then
            exit 1
        fi
    fi
    
    # Get bootstrap username
    if [[ -z "$BOOTSTRAP_USER" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}  YOUR USERNAME ON TARGET SERVER${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "The script needs to SSH to the target server"
        print_info "Enter the username YOU use to login to that server"
        echo ""
        echo -e "${BOLD}What is this?${NC}"
        echo "  • This is YOUR personal account on the target server"
        echo "  • The account you can SSH with RIGHT NOW"
        echo "  • Used to copy keys to the ansible automation account"
        echo ""
        print_warning "Common usernames:"
        echo "  • nantwi        (your personal username)"
        echo "  • vagrant       (if using Vagrant VMs)"
        echo "  • ubuntu        (default on Ubuntu cloud images)"
        echo "  • your-name     (whatever you created)"
        echo ""
        echo -e "${BOLD}${RED}NOT '$ANSIBLE_USER' - that's the automation account we're setting up!${NC}"
        echo ""
        echo -e "${BOLD}Example:${NC}"
        echo "  If you normally SSH with: ${CYAN}ssh nantwi@$SERVER_IP${NC}"
        echo "  Then enter: ${GREEN}nantwi${NC}"
        echo ""
        read -p "Your username on target server: " BOOTSTRAP_USER
        
        if [[ -z "$BOOTSTRAP_USER" ]]; then
            print_error "Username is required"
            exit 1
        fi
        
        # Warn if they entered automation user
        if [[ "$BOOTSTRAP_USER" == "$ANSIBLE_USER" ]]; then
            echo ""
            print_error "'$ANSIBLE_USER' is the automation account (not set up yet!)"
            print_error "You need a personal account that can SSH to the server"
            echo ""
            echo -e "${BOLD}If you don't have a personal account on the target:${NC}"
            echo "  1. SSH to target as root or another user"
            echo "  2. Create your personal account"
            echo "  3. Then run this script"
            echo ""
            exit 1
        fi
        
        # Warn if they entered 'root'
        if [[ "$BOOTSTRAP_USER" == "root" ]]; then
            print_warning "Using 'root' is not recommended for security"
            print_info "Consider creating a personal account instead"
            echo ""
            read -p "Continue with root? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Ask about special modes if not already set via environment
    if [[ -z "${DRY_RUN_SET:-}" ]] && [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}  OPERATION MODE${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${BOLD}Do you want to run in TEST mode (recommended for first time)?${NC}"
        echo ""
        echo -e "${GREEN}DRY RUN mode:${NC}"
        echo "  • Shows what WOULD be done without making changes"
        echo "  • Safe to run multiple times"
        echo "  • Tests connectivity and validates setup"
        echo "  • No modifications to target server or inventory"
        echo ""
        echo -e "${YELLOW}NORMAL mode:${NC}"
        echo "  • Actually makes changes"
        echo "  • Copies SSH keys"
        echo "  • Adds server to inventory"
        echo "  • Sets up Ansible management"
        echo ""
        read -p "Run in DRY RUN (test) mode? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            DRY_RUN="true"
            print_success "Running in DRY RUN mode (no changes will be made)"
        else
            print_info "Running in NORMAL mode (will make actual changes)"
        fi
        echo ""
    fi
    
    # Ask about verbose mode if not already set
    if [[ -z "${VERBOSE_SET:-}" ]] && [[ "$VERBOSE" == "false" ]]; then
        echo -e "${BOLD}Enable VERBOSE mode (detailed output)?${NC}"
        echo ""
        echo -e "${GREEN}VERBOSE mode:${NC}"
        echo "  • Shows all commands being executed"
        echo "  • Helpful for troubleshooting"
        echo "  • More technical output"
        echo ""
        echo -e "${YELLOW}NORMAL mode:${NC}"
        echo "  • Clean, simple output"
        echo "  • Recommended for regular use"
        echo ""
        read -p "Enable VERBOSE mode? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            VERBOSE="true"
            print_success "Verbose mode enabled"
        else
            print_info "Normal output mode"
        fi
        echo ""
    fi
    
    # Display configuration
    echo ""
    print_header "Configuration Summary"
    echo -e "${BOLD}System Information:${NC}"
    echo "  Script User:      $ACTUAL_USER"
    echo "  Home Directory:   $ACTUAL_HOME"
    echo ""
    echo -e "${BOLD}Target Server:${NC}"
    echo "  IP Address:       $SERVER_IP"
    echo "  Your Username:    $BOOTSTRAP_USER (your account on target)"
    echo "  Ansible User:     $ANSIBLE_USER (automation account to setup)"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo "  SSH Key:          ${ANSIBLE_KEY}"
    echo "  Inventory File:   $INVENTORY_FILE"
    echo "  Log File:         $LOG_FILE"
    
    # Show special modes if enabled
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}⚠️  SPECIAL MODE:${NC}"
        echo "  DRY RUN:          Enabled (NO changes will be made)"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}ℹ  VERBOSE MODE:${NC} Enabled (detailed output)"
    fi
    
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