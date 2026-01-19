#!/usr/bin/env bash
################################################################################
# Ansible Server Finalization Script (Controller-side)
#
# Version: 2.2.0
#
# Purpose:
#   Completes Ansible integration AFTER you run server-bootstrap.sh on the target.
#
# Key features:
#   - Interactive guided flow (like your earlier script)
#   - DRY RUN mode (interactive + env var)
#   - VERBOSE mode (interactive + env var)
#   - Detects target automation user
#   - Copies controller SSH key into target authorized_keys
#   - Handles sudo correctly:
#       ✅ passwordless sudo
#       ✅ sudo with password (prompts once, hidden, reused)
#       ❌ no sudo privileges at all -> stops early with exact fix steps
#
# IMPORTANT:
#   Run this on the controller as your normal user (e.g., svc-ansible).
#   DO NOT run with sudo.
################################################################################

set -euo pipefail

SCRIPT_VERSION="2.2.0"

# ------------------------------------------------------------------------------
# Detect actual user/home even if user mistakenly runs with sudo
# ------------------------------------------------------------------------------
if [[ -n "${SUDO_USER:-}" ]]; then
  ACTUAL_USER="$SUDO_USER"
  ACTUAL_HOME="$(getent passwd "$SUDO_USER" | awk -F: '{print $6}')"
else
  ACTUAL_USER="${USER:-$(whoami)}"
  ACTUAL_HOME="${HOME:-$(getent passwd "$(whoami)" | awk -F: '{print $6}')}"
fi

# ------------------------------------------------------------------------------
# Defaults / config (override via env vars if desired)
# ------------------------------------------------------------------------------
ANSIBLE_KEY="${ANSIBLE_SSH_KEY:-${ACTUAL_HOME}/.ssh/ansible-automation-key}"
INVENTORY_FILE="${ANSIBLE_INVENTORY:-/etc/ansible/hosts}"

# Modes (can be set via env vars)
if [[ -n "${DRY_RUN:-}" ]]; then DRY_RUN_SET="true"; else DRY_RUN="false"; fi
if [[ -n "${VERBOSE:-}" ]]; then VERBOSE_SET="true"; else VERBOSE="false"; fi

LOG_FILE="/tmp/ansible-finalize-$(date +%Y%m%d-%H%M%S).log"

# ------------------------------------------------------------------------------
# UI helpers
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${RESET} $*" | tee -a "$LOG_FILE"; }
print_error()   { echo -e "${RED}✗${RESET} $*" | tee -a "$LOG_FILE"; }
print_info()    { echo -e "${BLUE}ℹ${RESET} $*" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}⚠${RESET} $*" | tee -a "$LOG_FILE"; }

print_header() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${CYAN}  $*${RESET}" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# ------------------------------------------------------------------------------
# Globals
# ------------------------------------------------------------------------------
SERVER_IP=""
BOOTSTRAP_USER=""
TARGET_ANSIBLE_USER="ansible"
SUDO_MODE="unknown"   # one of: passwordless | with_password | none
SUDO_PASS=""          # stored in-memory for this run
ADDED_TO_INVENTORY="false"
SERVER_IP_GLOBAL=""

rollback() {
  if [[ "$ADDED_TO_INVENTORY" == "true" ]] && [[ -n "$SERVER_IP_GLOBAL" ]]; then
    print_warning "Rolling back: removing $SERVER_IP_GLOBAL from inventory..."
    if [[ -f "$INVENTORY_FILE" ]]; then
      sudo sed -i.bak "/^${SERVER_IP_GLOBAL}[[:space:]]/d" "$INVENTORY_FILE" 2>/dev/null || true
    fi
  fi
}
trap rollback ERR

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
require_cmds() {
  local missing=()
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if ((${#missing[@]})); then
    print_error "Missing commands: ${missing[*]}"
    return 1
  fi
  return 0
}

check_prerequisites() {
  print_info "Checking controller prerequisites..."
  require_cmds ssh awk sed grep tee stat ansible || return 1
  print_success "Prerequisites OK"
}

check_ssh_keypair() {
  print_info "Checking SSH key: $ANSIBLE_KEY"
  print_info "Running as: $ACTUAL_USER (home: $ACTUAL_HOME)"

  if [[ ! -f "$ANSIBLE_KEY" ]]; then
    print_error "Private key not found: $ANSIBLE_KEY"
    print_info "Generate it with:"
    echo "  ssh-keygen -t ed25519 -f \"$ANSIBLE_KEY\" -C 'ansible-automation'"
    return 1
  fi

  if [[ ! -f "${ANSIBLE_KEY}.pub" ]]; then
    print_error "Public key not found: ${ANSIBLE_KEY}.pub"
    return 1
  fi

  local p
  p="$(stat -c%a "$ANSIBLE_KEY" 2>/dev/null || echo "")"
  if [[ "$p" != "600" ]]; then
    print_warning "Fixing key permissions ($p -> 600)"
    chmod 600 "$ANSIBLE_KEY"
  fi

  print_success "SSH keypair found"
}

validate_ip() {
  local ip="$1"
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local IFS='.'
    read -r a b c d <<< "$ip"
    for o in "$a" "$b" "$c" "$d"; do
      if ((o < 0 || o > 255)); then
        print_error "Invalid IP: $ip"
        return 1
      fi
    done
    return 0
  fi
  print_error "Invalid IP format: $ip"
  return 1
}

ssh_cmd() {
  local user="$1" ip="$2" cmd="$3"
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${user}@${ip}" "$cmd"
}

# ------------------------------------------------------------------------------
# Interactive start (restores your older “guided” behavior)
# ------------------------------------------------------------------------------
interactive_modes() {
  if [[ -z "${DRY_RUN_SET:-}" ]]; then
    print_header "Operation Mode"
    echo "  1) DRY RUN  (safe test - no changes)"
    echo "  2) NORMAL   (apply changes)"
    echo ""
    read -r -p "Select option (1-2) [1]: " mode_choice
    mode_choice="${mode_choice:-1}"
    case "$mode_choice" in
      1) DRY_RUN="true";  print_success "DRY RUN enabled (no changes will be made)";;
      2) DRY_RUN="false"; print_info "NORMAL mode selected (changes will be applied)";;
      *) DRY_RUN="true";  print_warning "Invalid selection; defaulting to DRY RUN";;
    esac
  fi

  if [[ -z "${VERBOSE_SET:-}" ]]; then
    echo ""
    read -r -p "Enable VERBOSE mode (more troubleshooting output)? (y/n) [n]: " vchoice
    vchoice="${vchoice:-n}"
    if [[ "$vchoice" =~ ^[Yy]$ ]]; then
      VERBOSE="true"
      print_success "VERBOSE mode enabled"
    else
      VERBOSE="false"
      print_info "VERBOSE mode disabled"
    fi
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    set -x
  fi
}

prompt_target_details() {
  print_header "Target Server"
  while true; do
    read -r -p "Target server IP: " SERVER_IP
    [[ -n "$SERVER_IP" ]] || { print_error "IP is required"; continue; }
    validate_ip "$SERVER_IP" && break
  done

  print_header "Bootstrap User"
  read -r -p "Your username on target (e.g., tcm, vagrant, ubuntu): " BOOTSTRAP_USER
  BOOTSTRAP_USER="${BOOTSTRAP_USER:-}"
  if [[ -z "$BOOTSTRAP_USER" ]]; then
    print_error "Bootstrap user is required"
    exit 1
  fi
}

show_config_summary() {
  print_header "Configuration Summary"
  echo -e "${BOLD}Target:${NC}"
  echo "  IP:             $SERVER_IP"
  echo "  Bootstrap user:  $BOOTSTRAP_USER"
  echo ""
  echo -e "${BOLD}Controller:${NC}"
  echo "  User:           $ACTUAL_USER"
  echo "  Home:           $ACTUAL_HOME"
  echo "  SSH key:        $ANSIBLE_KEY"
  echo "  Inventory:      $INVENTORY_FILE"
  echo ""
  echo -e "${BOLD}Modes:${NC}"
  echo "  DRY_RUN:        $DRY_RUN"
  echo "  VERBOSE:        $VERBOSE"
  echo ""
  echo -e "${BOLD}Log:${NC}"
  echo "  $LOG_FILE"
  echo ""
  read -r -p "Continue? (y/n): " yn
  yn="${yn:-n}"
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    print_warning "Cancelled by user"
    exit 0
  fi
}

# ------------------------------------------------------------------------------
# Step 1: Connectivity
# ------------------------------------------------------------------------------
test_connectivity() {
  print_header "Step 1: Connectivity Check"
  print_info "Testing connectivity to ${BOOTSTRAP_USER}@${SERVER_IP}..."
  if ssh_cmd "$BOOTSTRAP_USER" "$SERVER_IP" "echo Connected" >/dev/null 2>&1; then
    print_success "Can connect to server as $BOOTSTRAP_USER"
  else
    print_error "Cannot SSH to ${BOOTSTRAP_USER}@${SERVER_IP}"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Sudo detection (FIXED)
# ------------------------------------------------------------------------------
detect_sudo_mode() {
  print_header "Step 2: Sudo Capability Check (Bootstrap User)"

  # 1) Passwordless sudo?
  if ssh_cmd "$BOOTSTRAP_USER" "$SERVER_IP" "sudo -n true" >/dev/null 2>&1; then
    SUDO_MODE="passwordless"
    print_success "Passwordless sudo IS enabled for '${BOOTSTRAP_USER}' on target."
    return 0
  fi

  # 2) Can sudo with password? (prompt once)
  print_warning "Passwordless sudo is NOT enabled for '${BOOTSTRAP_USER}' on target."
  print_info "To let the script handle everything, it can use sudo WITH your password (prompted once, hidden)."
  echo ""
  read -r -s -p "Enter sudo password for ${BOOTSTRAP_USER}@${SERVER_IP}: " SUDO_PASS
  echo ""

  if [[ -z "$SUDO_PASS" ]]; then
    print_error "No password entered. Cannot proceed automatically."
    SUDO_MODE="none"
    return 1
  fi

  # Validate sudo works (this also detects: user not in sudoers)
  local out rc
  out="$(ssh -tt -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${BOOTSTRAP_USER}@${SERVER_IP}" \
    "printf '%s\n' '$SUDO_PASS' | sudo -S -p '' -v" 2>&1 )" || rc=$?
  rc="${rc:-0}"

  if [[ "$rc" -eq 0 ]]; then
    SUDO_MODE="with_password"
    print_success "Sudo works WITH password for '${BOOTSTRAP_USER}'. (Password cached for this run)"
    return 0
  fi

  # If sudo fails, we must STOP (cannot fix sudo without sudo)
  SUDO_MODE="none"
  print_error "Bootstrap user '${BOOTSTRAP_USER}' cannot run sudo on the target."
  echo ""
  print_info "What this means:"
  echo "  • '${BOOTSTRAP_USER}' is likely NOT in the 'sudo' group and NOT in sudoers."
  echo "  • The script cannot create sudo rules or fix permissions without sudo access."
  echo ""
  print_info "Fix options (pick ONE):"
  echo ""
  echo "Option A (recommended): Add '${BOOTSTRAP_USER}' to sudo group on target (requires an admin account):"
  echo "  sudo usermod -aG sudo ${BOOTSTRAP_USER}"
  echo "  # then log out/in and rerun this script"
  echo ""
  echo "Option B: Use a different bootstrap user that already has sudo (e.g., vagrant/ubuntu/root):"
  echo "  Rerun and enter that username when asked."
  echo ""
  print_info "Sudo error details captured:"
  echo "$out" | sed 's/^/  /'
  echo ""
  return 1
}

remote_sudo() {
  local cmd="$1"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would run on target as root: $cmd"
    return 0
  fi

  case "$SUDO_MODE" in
    passwordless)
      ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${BOOTSTRAP_USER}@${SERVER_IP}" \
        "sudo bash -lc $(printf '%q' "$cmd")"
      ;;
    with_password)
      ssh -tt -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${BOOTSTRAP_USER}@${SERVER_IP}" \
        "printf '%s\n' '$SUDO_PASS' | sudo -S -p '' bash -lc $(printf '%q' "$cmd")"
      ;;
    *)
      print_error "remote_sudo called but SUDO_MODE is '$SUDO_MODE' (this is a script bug)"
      return 1
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Target automation user detection
# ------------------------------------------------------------------------------
detect_target_automation_user() {
  print_header "Step 3: Detect Target Automation User"

  local out
  out="$(ssh_cmd "$BOOTSTRAP_USER" "$SERVER_IP" \
    "getent passwd | awk -F: '\$3>=1000 && \$3<65534 {print \$1\":\"\$3\":\"\$6}' | grep -E '(ansible|automation|svc)'" \
    2>/dev/null || true)"

  if [[ -z "$out" ]]; then
    print_warning "No obvious automation user found on target."
    echo "  1) Use 'ansible'"
    echo "  2) Enter a username"
    echo ""
    read -r -p "Choose (1-2) [1]: " c
    c="${c:-1}"
    if [[ "$c" == "2" ]]; then
      read -r -p "Enter target automation username: " TARGET_ANSIBLE_USER
      TARGET_ANSIBLE_USER="${TARGET_ANSIBLE_USER:-ansible}"
    else
      TARGET_ANSIBLE_USER="ansible"
    fi
    print_info "Will use target automation user: $TARGET_ANSIBLE_USER"
    return 0
  fi

  mapfile -t lines <<< "$out"
  if ((${#lines[@]} == 1)); then
    local u uid home
    IFS=':' read -r u uid home <<< "${lines[0]}"
    print_success "Found automation user on target: $u"
    echo ""
    echo -e "${BOLD}User details:${NC}"
    echo "  $u (uid: $uid, home: $home)"
    echo ""
    read -r -p "Use '$u' as target automation user? (y/n) [y]: " yn
    yn="${yn:-y}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      TARGET_ANSIBLE_USER="$u"
    else
      read -r -p "Enter target automation username: " TARGET_ANSIBLE_USER
      TARGET_ANSIBLE_USER="${TARGET_ANSIBLE_USER:-ansible}"
    fi
    print_success "Target automation user set to: $TARGET_ANSIBLE_USER"
    return 0
  fi

  print_success "Found multiple potential automation users:"
  echo ""
  local i=1
  for l in "${lines[@]}"; do
    local u uid home
    IFS=':' read -r u uid home <<< "$l"
    echo "  $i) $u (uid: $uid, home: $home)"
    ((i++))
  done
  echo "  $i) Enter different username"
  echo ""
  read -r -p "Select option (1-$i): " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
    local u uid home
    IFS=':' read -r u uid home <<< "${lines[$((choice-1))]}"
    TARGET_ANSIBLE_USER="$u"
  else
    read -r -p "Enter target automation username: " TARGET_ANSIBLE_USER
    TARGET_ANSIBLE_USER="${TARGET_ANSIBLE_USER:-ansible}"
  fi

  print_success "Target automation user set to: $TARGET_ANSIBLE_USER"
}

verify_target_user_exists() {
  print_header "Step 4: Verify Target Automation User Exists"
  print_info "Checking '$TARGET_ANSIBLE_USER' on target..."
  if ssh_cmd "$BOOTSTRAP_USER" "$SERVER_IP" "id '$TARGET_ANSIBLE_USER' >/dev/null 2>&1"; then
    print_success "User '$TARGET_ANSIBLE_USER' confirmed on target"
  else
    print_error "User '$TARGET_ANSIBLE_USER' does NOT exist on target"
    return 1
  fi
}

get_target_home() {
  ssh_cmd "$BOOTSTRAP_USER" "$SERVER_IP" "getent passwd '$TARGET_ANSIBLE_USER' | awk -F: '{print \$6}'"
}

# ------------------------------------------------------------------------------
# Copy SSH key (idempotent, fixes ownership correctly)
# ------------------------------------------------------------------------------
copy_key_to_target() {
  print_header "Step 5: Copy SSH Key to Target"

  local pub_key key_part
  pub_key="$(cat "${ANSIBLE_KEY}.pub")"
  key_part="$(echo "$pub_key" | awk '{print $1" "$2}')"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would ensure ~/.ssh and append key for '$TARGET_ANSIBLE_USER' on $SERVER_IP"
    return 0
  fi

  local target_home ssh_dir auth_keys
  target_home="$(get_target_home)"
  if [[ -z "$target_home" ]]; then
    print_error "Could not determine home directory for $TARGET_ANSIBLE_USER"
    return 1
  fi

  ssh_dir="${target_home}/.ssh"
  auth_keys="${ssh_dir}/authorized_keys"

  print_info "Ensuring ${ssh_dir} and ${auth_keys} exist with correct permissions..."
  remote_sudo "
    set -e
    mkdir -p '$ssh_dir'
    chmod 700 '$ssh_dir'
    touch '$auth_keys'
    chmod 600 '$auth_keys'
    chown -R '$TARGET_ANSIBLE_USER:$TARGET_ANSIBLE_USER' '$ssh_dir'
    grep -qF '$key_part' '$auth_keys' || echo '$pub_key' >> '$auth_keys'
    chown '$TARGET_ANSIBLE_USER:$TARGET_ANSIBLE_USER' '$auth_keys'
    chmod 600 '$auth_keys'
  "

  print_success "SSH key is in place for ${TARGET_ANSIBLE_USER}@${SERVER_IP}"
}

# ------------------------------------------------------------------------------
# Test automation user SSH + sudo
# ------------------------------------------------------------------------------
test_automation_access() {
  print_header "Step 6: Test SSH & Passwordless Sudo (Automation User)"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would test ssh and sudo for ${TARGET_ANSIBLE_USER}@${SERVER_IP}"
    return 0
  fi

  print_info "Testing SSH login as ${TARGET_ANSIBLE_USER} using key..."
  if ssh -i "$ANSIBLE_KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
      "${TARGET_ANSIBLE_USER}@${SERVER_IP}" "whoami" 2>/dev/null | grep -qx "$TARGET_ANSIBLE_USER"; then
    print_success "SSH key auth works for ${TARGET_ANSIBLE_USER}"
  else
    print_error "SSH key auth FAILED for ${TARGET_ANSIBLE_USER}"
    print_info "Debug with:"
    echo "  ssh -vvv -i \"$ANSIBLE_KEY\" ${TARGET_ANSIBLE_USER}@${SERVER_IP}"
    return 1
  fi

  print_info "Testing passwordless sudo as ${TARGET_ANSIBLE_USER}..."
  if ssh -i "$ANSIBLE_KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
      "${TARGET_ANSIBLE_USER}@${SERVER_IP}" "sudo -n whoami" 2>/dev/null | grep -qx "root"; then
    print_success "Passwordless sudo: OK"
  else
    print_error "Passwordless sudo: FAILED for ${TARGET_ANSIBLE_USER}"
    print_info "This must be set by your bootstrap script on the target."
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Inventory + Ansible ping
# ------------------------------------------------------------------------------
add_to_inventory() {
  print_header "Step 7: Add Target to Inventory"

  local hostname
  hostname="$(ssh -i "$ANSIBLE_KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    "${TARGET_ANSIBLE_USER}@${SERVER_IP}" "hostname" 2>/dev/null || true)"
  hostname="${hostname:-$SERVER_IP}"

  print_info "Inventory: $INVENTORY_FILE"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would add:"
    echo "  ${SERVER_IP}   # ${hostname} - Added $(date '+%Y-%m-%d %H:%M:%S')"
    return 0
  fi

  if [[ ! -d /etc/ansible ]]; then
    print_warning "/etc/ansible does not exist; creating..."
    sudo mkdir -p /etc/ansible
  fi

  if [[ ! -f "$INVENTORY_FILE" ]]; then
    print_warning "Inventory file missing; creating $INVENTORY_FILE"
    sudo tee "$INVENTORY_FILE" >/dev/null <<EOF
# Ansible Inventory File
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Format: IP_ADDRESS   # HOSTNAME - DESCRIPTION

EOF
    sudo chmod 644 "$INVENTORY_FILE"
  fi

  if grep -qE "^${SERVER_IP}[[:space:]]" "$INVENTORY_FILE" 2>/dev/null; then
    print_info "Already present in inventory"
    return 0
  fi

  local entry="${SERVER_IP}   # ${hostname} - Added $(date '+%Y-%m-%d %H:%M:%S')"
  echo "$entry" | sudo tee -a "$INVENTORY_FILE" >/dev/null
  ADDED_TO_INVENTORY="true"
  SERVER_IP_GLOBAL="$SERVER_IP"

  print_success "Added to inventory"
}

ansible_ping_test() {
  print_header "Step 8: Ansible Connectivity Test"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would run:"
    echo "  ansible ${SERVER_IP} -m ping --user ${TARGET_ANSIBLE_USER} --private-key ${ANSIBLE_KEY}"
    return 0
  fi

  local opts="-m ping --user ${TARGET_ANSIBLE_USER} --private-key ${ANSIBLE_KEY}"
  if [[ "$VERBOSE" == "true" ]]; then
    opts="$opts -vvv"
  fi

  print_info "Running: ansible ${SERVER_IP} $opts"
  if ansible "${SERVER_IP}" $opts 2>&1 | tee -a "$LOG_FILE" | grep -q "SUCCESS"; then
    print_success "Ansible ping: SUCCESS"
  else
    print_warning "Ansible ping did not return SUCCESS"
    print_info "Try manually:"
    echo "  ansible \"${SERVER_IP},\" -m ping --user ${TARGET_ANSIBLE_USER} --private-key ${ANSIBLE_KEY} -vvv"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  : > "$LOG_FILE"
  clear

  print_header "Ansible Server Finalization v${SCRIPT_VERSION}"
  print_info "Controller user: $ACTUAL_USER"
  print_info "Controller home: $ACTUAL_HOME"
  print_info "Log file: $LOG_FILE"

  if [[ -n "${SUDO_USER:-}" ]]; then
    print_warning "You ran this with sudo. Not recommended."
    print_warning "Run without sudo as your normal controller user."
    echo ""
  fi

  check_prerequisites
  check_ssh_keypair

  interactive_modes
  prompt_target_details
  show_config_summary

  test_connectivity
  detect_sudo_mode               # <-- FIXED behavior here (no sudoers creation lies)
  detect_target_automation_user
  verify_target_user_exists
  copy_key_to_target
  test_automation_access
  add_to_inventory
  ansible_ping_test

  print_header "Done"
  print_success "Target ${SERVER_IP} is ready for Ansible management as '${TARGET_ANSIBLE_USER}'"
  echo ""
  echo "Try:"
  echo "  ansible ${SERVER_IP} -m ping --user ${TARGET_ANSIBLE_USER} --private-key ${ANSIBLE_KEY}"
  echo ""
  print_info "Log: $LOG_FILE"
}

main "$@"
