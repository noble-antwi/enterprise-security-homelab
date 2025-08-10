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
private_key_file = ~/.ssh/id_ed25519
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

## 📦 Playbook Execution Issues

### Issue 4: Mixed Operating System Package Management

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
```

---

*Ansible Automation Troubleshooting Guide | Updated: August 2025*