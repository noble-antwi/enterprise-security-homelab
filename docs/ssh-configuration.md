# SSH Configuration Guide

## 📖 Overview

This guide documents the SSH configuration setup for seamless authentication and friendly hostname access across the enterprise homelab infrastructure.

## 🔑 SSH Key Management

### Key Naming Convention
- **Lab Infrastructure**: `ansible-automation-key` (ED25519)
- **GitHub Access**: `blueteam-homelab-github` (ED25519)

### Key Generation
```bash
# Generate lab infrastructure key
ssh-keygen -t ed25519 -f ~/.ssh/ansible-automation-key -C "ansible-lab@homelab-infrastructure"

# Generate GitHub access key
ssh-keygen -t ed25519 -f ~/.ssh/blueteam-homelab-github -C "github-access@homelab"
```

## 🔧 SSH Configuration File

### Location
`~/.ssh/config`

### Complete Configuration
```bash
# GitHub Access Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/blueteam-homelab-github
    IdentitiesOnly yes

# Lab Infrastructure SSH Configuration
Host 192.168.*
    IdentityFile ~/.ssh/ansible-automation-key
    User nantwi
    IdentitiesOnly yes

# Specific Lab Systems
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

## 🎯 Usage Examples

### Friendly Hostname Access
```bash
# Connect using memorable names instead of IP addresses
ssh wazuh-server        # Connects to 192.168.20.2
ssh monitoring-server   # Connects to 192.168.60.2
ssh tcm-ubuntu          # Connects to 192.168.10.4
```

### File Transfer Operations
```bash
# SCP with friendly hostnames
scp myfile.txt wazuh-server:/tmp/
scp monitoring-server:/var/log/grafana.log ./

# Rsync backups
rsync -av /local/config/ monitoring-server:/backup/
```

### Ansible Integration
```bash
# Ansible works seamlessly with SSH config
ansible wazuh-server -m ping
ansible monitoring-server -m shell -a "uptime"
```

## 🔒 Security Benefits

### Key Separation
- **Purpose-specific keys** prevent credential overlap
- **GitHub key** isolated from infrastructure access
- **Lab key** dedicated to internal systems only

### Automatic Key Selection
- **No manual key specification** required in commands
- **Prevents authentication failures** from wrong key usage
- **Improved security** through explicit key-to-host mapping

### Access Control
- **IdentitiesOnly yes** prevents SSH from trying unwanted keys
- **User specification** ensures consistent authentication context
- **Host-specific configuration** enables granular access control

## 📊 Performance Impact

### Connection Speed
- **Direct key selection** eliminates key trial-and-error
- **Reduced authentication overhead** for faster connections
- **Optimized for automation** with predictable behavior

### Operational Efficiency
- **Memorable hostnames** improve daily workflow
- **Consistent commands** across different systems
- **Professional infrastructure** management practices

## 🛠️ Troubleshooting

### Key Permission Issues
```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/ansible-automation-key
chmod 644 ~/.ssh/ansible-automation-key.pub
chmod 600 ~/.ssh/config
```

### Connection Testing
```bash
# Test SSH connection with verbose output
ssh -v wazuh-server

# Verify key selection
ssh-add -l  # List loaded keys
```

### Configuration Validation
```bash
# Test SSH config parsing
ssh -F ~/.ssh/config -T wazuh-server
```

## 🎯 Best Practices

### Key Management
✅ **Use descriptive key names** for easy identification  
✅ **Separate keys by purpose** (infrastructure vs. external services)  
✅ **Regular key rotation** for enhanced security  
✅ **Backup key pairs** securely  

### SSH Configuration
✅ **Document all host entries** with clear purposes  
✅ **Use IdentitiesOnly** to prevent key conflicts  
✅ **Group related hosts** logically in config file  
✅ **Test configuration changes** before deployment  

### Operational Security
✅ **Monitor SSH access logs** for security events  
✅ **Regular access review** of configured hosts  
✅ **Implement proper file permissions** for all SSH files  
✅ **Use modern key algorithms** (ED25519 preferred)  

---

*SSH Configuration Guide | Optimized for Enterprise Homelab Operations*