# 🔧 Ansible Automation Troubleshooting

## 📖 Overview

This guide covers common issues encountered with Ansible automation platform configuration and operation within the enterprise homelab environment.

## ⚙️ Ansible Configuration Issues

### Issue 1: Ansible Configuration Not Loading Properly

#### **Problem Description**
Ansible configuration file appears correct but settings are not being applied, resulting in continued requirement for command-line flags and "Missing sudo password" errors.

#### **Symptoms**
- Commands still require `--ask-become-pass` flag despite `ask_sudo_pass = true`
- `ansible-config dump --only-changed | grep ASK_SUDO_PASS` returns no output
- Configuration file exists and appears syntactically correct
- Playbooks fail with "Missing sudo password" errors

#### **Root Cause Analysis**
Common causes include:
- Configuration file not saved properly
- Incorrect file permissions
- Ansible loading configuration from different location
- Syntax errors in configuration file
- Multiple configuration files creating conflicts

#### **Solution Process**
```bash
# 1. Verify configuration file content
sudo cat /etc/ansible/ansible.cfg

# 2. Check if configuration is being loaded
ansible-config dump | grep ASK_SUDO_PASS

# 3. Verify file permissions
ls -la /etc/ansible/ansible.cfg

# 4. Create user-level configuration as alternative
mkdir -p ~/.ansible
nano ~/.ansible/ansible.cfg

# 5. Test configuration loading
ansible-config dump --only-changed | grep ASK_SUDO_PASS
```

#### **Alternative Solution: User-Level Configuration**
```bash
# Create user-specific ansible directory
mkdir -p ~/.ansible

# Create user-level configuration file
nano ~/.ansible/ansible.cfg
```

**User-level configuration content:**
```ini
[defaults]
inventory = /etc/ansible/hosts
private_key_file = ~/.ssh/ansible-automation-key
remote_user = nantwi
ask_pass = false
ask_sudo_pass = true
interpreter_python = auto_silent
host_key_checking = false
```

#### **Verification Commands**
```bash
# Test configuration loading
ansible-config view

# Verify specific settings
ansible-config dump --only-changed | grep -E "(ASK_SUDO_PASS|REMOTE_USER|PRIVATE_KEY)"

# Test sudo prompting
ansible all_in_one -m shell -a "sudo whoami"
```

#### **Prevention Strategies**
✅ **Test immediately** after configuration changes  
✅ **Use ansible-config view** to verify active configuration  
✅ **Check multiple configuration locations** (~/.ansible/, ./ansible.cfg, /etc/ansible/)  
✅ **Verify file permissions** and ownership  
✅ **Use user-level config** as backup option  

### Issue 2: Cross-Platform Package Management Failures

#### **Problem Description**
Playbooks fail when managing packages across different operating systems due to different package managers and repository requirements.

#### **Symptoms**
- `dnf` commands fail on Ubuntu systems
- `apt` commands fail on Rocky Linux systems
- Package not found errors on specific distributions
- EPEL repository requirements not met on RHEL-based systems

#### **Root Cause**
Different Linux distributions use different package managers and have different default repositories:
- **Ubuntu/Debian**: Uses `apt` package manager
- **Rocky Linux/RHEL/CentOS**: Uses `dnf` or `yum` package manager
- **Package Names**: May differ between distributions
- **Repository Requirements**: Some packages require additional repositories (EPEL)

#### **Solution Implementation**
```yaml
# OS Detection and Conditional Package Management
- name: Install package on Ubuntu/Debian
  apt:
    name: "{{ package_name }}"
    state: present
    update_cache: true
  when: ansible_distribution in ["Ubuntu", "Debian"]

- name: Enable EPEL repository on RHEL-based systems
  dnf:
    name: epel-release
    state: present
  when: ansible_distribution in ["Rocky", "RedHat", "CentOS"]

- name: Install package on RHEL-based systems
  dnf:
    name: "{{ package_name }}"
    state: present
    update_cache: true
  when: ansible_distribution in ["Rocky", "RedHat", "CentOS"]
```

#### **Best Practices for Cross-Platform Playbooks**
✅ **Use conditional statements** based on `ansible_distribution`  
✅ **Handle repository requirements** (EPEL, universe, etc.)  
✅ **Include verification tasks** to confirm installation  
✅ **Implement error handling** for failed installations  
✅ **Test across all target distributions** before deployment  

#### **Verification Framework**
```yaml
# Verification and error handling
- name: Verify package installation
  command: "{{ package_name }} --version"
  register: package_version
  changed_when: false
  failed_when: false

- name: Report installation status
  debug:
    msg: "{{ package_name }} installed: {{ package_version.stdout }}"
  when: package_version.rc == 0
```

## 🔑 SSH Key Management Issues

### Issue 3: SSH Keys Located in Root Account

#### **Problem Description**
SSH keys generated under root account (`/root/.ssh/`) but Ansible running as regular user, causing authentication failures.

#### **Symptoms**
- Ansible commands require password authentication
- SSH keys exist but not accessible to user account
- `ls ~/.ssh/` shows no `id_ed25519` files for regular user

#### **Root Cause**
SSH keys were generated using `sudo ssh-keygen` or while logged in as root, placing keys in `/root/.ssh/` instead of user's home directory.

#### **Solution Process**
```bash
# 1. As root, copy keys to user directory
sudo cp /root/.ssh/id_ed25519* /home/nantwi/.ssh/

# 2. Fix ownership
sudo chown nantwi:nantwi /home/nantwi/.ssh/id_ed25519*

# 3. Set correct permissions
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# 4. Verify keys are accessible
ls -la ~/.ssh/id_ed25519*
```

#### **Prevention**
✅ **Generate SSH keys as regular user** (not root)  
✅ **Use user-level directories** for automation keys  
✅ **Test key access** immediately after generation  
✅ **Verify key distribution** to managed systems  

### Issue 4: SSH Key Rename and Configuration

#### **Problem Description**
After renaming SSH keys from default names (`id_ed25519`) to custom names (`ansible-automation-key`), SSH connections may require password authentication or fail to connect automatically.

#### **Symptoms**
- Password prompts when using `ssh user@host` (without `-i` flag)
- Need to specify key manually: `ssh -i ~/.ssh/custom-key user@host`
- Ansible may require additional configuration to find renamed keys

#### **Root Cause**
SSH automatically looks for keys with standard names (`id_rsa`, `id_ed25519`, etc.). Custom-named keys are not automatically discovered unless explicitly configured.

#### **Solution Implementation**

##### Step 1: Update Ansible Configuration
```bash
# Edit ansible.cfg to reference custom key
sudo nano /etc/ansible/ansible.cfg

# Update this line:
private_key_file = ~/.ssh/ansible-automation-key
```

##### Step 2: Create SSH Configuration File
```bash
# Create/edit SSH config
nano ~/.ssh/config

# Add lab infrastructure configuration:
Host 192.168.*
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi
    IdentitiesOnly yes

# Add friendly hostname aliases:
Host wazuh-server
    HostName 192.168.20.2
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi

Host monitoring-server
    HostName 192.168.60.2
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi

Host tcm-ubuntu
    HostName 192.168.10.4
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi

Host ansible-controller
    HostName 192.168.10.2
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi
```

##### Step 3: Set Proper Permissions
```bash
# Ensure correct file permissions
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/ansible-automation-key
chmod 644 ~/.ssh/ansible-automation-key.pub
```

#### **Verification Commands**
```bash
# Test SSH connections
ssh nantwi@192.168.20.2    # Should work without password
ssh wazuh-server           # Should work with friendly hostname

# Test Ansible connectivity
ansible all_in_one -m ping

# Verify SSH config with verbose output
ssh -v wazuh-server
```

#### **Benefits Achieved**
✅ **Friendly Hostnames**: Use memorable names like `ssh wazuh-server`  
✅ **Automatic Key Selection**: SSH chooses correct key automatically  
✅ **Professional Workflow**: Enterprise-grade infrastructure management  
✅ **Ansible Compatibility**: Seamless automation operations  

#### **Prevention Strategies**
✅ **Plan SSH config** before renaming keys  
✅ **Test configuration changes** incrementally  
✅ **Document key naming conventions** for consistency  
✅ **Backup SSH configuration** before modifications  

## 📦 Playbook Execution Issues

### Issue 5: Mixed Operating System Package Management

#### **Problem Description**
Playbooks designed for single OS type fail when executed against mixed infrastructure with Ubuntu and Rocky Linux systems.

#### **Symptoms**
- Ubuntu systems fail when playbook uses `dnf` module
- Rocky Linux systems fail when playbook uses `apt` module
- Package names differ between distributions
- Repository requirements vary by OS

#### **Solution: Conditional Task Execution**
```yaml
# Separate tasks for each OS family
- name: Install packages on Ubuntu/Debian
  apt:
    name: "{{ packages }}"
    state: present
    update_cache: true
  when: ansible_distribution in ["Ubuntu", "Debian"]

- name: Install packages on Rocky/RHEL
  dnf:
    name: "{{ packages }}"
    state: present
    update_cache: true
  when: ansible_distribution in ["Rocky", "RedHat", "CentOS"]
```

#### **Enhanced Cross-Platform Example**
```yaml
# Complete cross-platform package management
- name: Install htop on Ubuntu/Debian systems
  apt:
    name: htop
    state: present
    update_cache: true
  when: ansible_distribution in ["Ubuntu", "Debian"]

- name: Enable EPEL repository on Rocky/RHEL systems
  dnf:
    name: epel-release
    state: present
  when: ansible_distribution in ["Rocky", "RedHat", "CentOS", "AlmaLinux"]

- name: Install htop on Rocky/RHEL/CentOS systems
  dnf:
    name: htop
    state: present
    update_cache: true
  when: ansible_distribution in ["Rocky", "RedHat", "CentOS", "AlmaLinux"]

- name: Verify htop installation
  command: htop --version
  register: htop_version
  changed_when: false
  failed_when: false

- name: Display htop version
  debug:
    msg: "htop installed successfully: {{ htop_version.stdout }}"
  when: htop_version.rc == 0
```

## 🧪 Testing and Validation

### Comprehensive Testing Framework
```bash
# Test configuration
ansible-config dump --only-changed

# Test connectivity
ansible all_in_one -m ping

# Test privilege escalation
ansible all_in_one -m shell -a "sudo whoami"

# Test cross-platform compatibility
ansible all_in_one -m setup | grep ansible_distribution

# Test friendly hostnames
ssh wazuh-server "hostname"
ssh monitoring-server "hostname"
ssh tcm-ubuntu "hostname"
```

### SSH Configuration Testing
```bash
# Test SSH config parsing
ssh -F ~/.ssh/config -T wazuh-server

# Verify key selection
ssh -v monitoring-server 2>&1 | grep "Trying private key"

# Test all friendly hostnames
for host in wazuh-server monitoring-server tcm-ubuntu ansible-controller; do
    echo "Testing $host:"
    ssh $host "echo 'Connected to '$(hostname)"
done
```

### Ansible Configuration Validation
```bash
# Verify Ansible finds custom SSH key
ansible-config dump --only-changed | grep PRIVATE_KEY

# Test streamlined command execution
ansible all_in_one -m shell -a "sudo whoami"

# Run cross-platform playbook
ansible-playbook ansible/playbooks/install_htop.yml
```

## 🔍 Advanced Troubleshooting

### SSH Connection Debugging
```bash
# Verbose SSH connection for troubleshooting
ssh -vvv wazuh-server

# Check SSH agent status
ssh-add -l

# Test SSH config syntax
ssh -F ~/.ssh/config -T github.com  # Should work for GitHub
ssh -F ~/.ssh/config -T wazuh-server  # Test lab config
```

### Ansible Debug Commands
```bash
# Check which configuration file Ansible is using
ansible-config view

# Debug inventory parsing
ansible-inventory --list

# Test specific host connectivity
ansible wazuh-server -m ping -vvv

# Check SSH key permissions
ls -la ~/.ssh/ansible-automation-key*
```

### Performance Optimization
```bash
# Enable SSH connection reuse for faster operations
# Add to ~/.ssh/config:
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

# Create sockets directory
mkdir -p ~/.ssh/sockets
```

## 🎯 Best Practices Summary

### SSH Key Management
✅ **Use descriptive key names** for easy identification  
✅ **Separate keys by purpose** (infrastructure vs. external services)  
✅ **Implement SSH config** for automatic key selection  
✅ **Regular key rotation** for enhanced security  
✅ **Backup key pairs** securely  

### Ansible Configuration
✅ **Optimize ansible.cfg** for streamlined operations  
✅ **Test configuration changes** immediately  
✅ **Use cross-platform playbooks** for mixed environments  
✅ **Implement proper error handling** in playbooks  
✅ **Document automation workflows** for team collaboration  

### Operational Security
✅ **Monitor SSH access logs** for security events  
✅ **Regular access review** of configured hosts  
✅ **Implement proper file permissions** for all SSH files  
✅ **Use modern key algorithms** (ED25519 preferred)  
✅ **Maintain automation documentation** for troubleshooting  

---

*Ansible Automation Troubleshooting Guide | Updated with SSH Configuration Management | January 2026*