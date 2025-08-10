# 🖥️ System Administration Troubleshooting

## 🔧 Network Configuration Issues

### Issue 1: Netplan Gateway Deprecation Warnings

#### **Problem Description**
Ubuntu 24.04 systems generated deprecation warnings when using `gateway4` parameter in Netplan configuration.

#### **Symptoms**
```bash
sudo netplan apply
# Warning: `gateway4` has been deprecated, use default routes instead.
```

#### **Root Cause**
Netplan evolved to use modern routing syntax, deprecating the legacy `gateway4` parameter in favor of explicit route definitions.

#### **Legacy Configuration (Problematic)**
```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.10.2/24]
      gateway4: 192.168.10.1  # DEPRECATED
      nameservers:
        addresses: [8.8.8.8]
```

#### **Modern Configuration (Solution)**
```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses:
        - 192.168.10.2/24
      routes:
        - to: 0.0.0.0/0
          via: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

#### **Implementation Process**
```bash
# 1. Update configuration file
sudo nano /etc/netplan/50-cloud-init.yaml

# 2. Apply configuration
sudo netplan apply

# 3. Test connectivity
ping 192.168.10.1  # Gateway
ping 8.8.8.8       # Internet
```

---

### Issue 2: Netplan File Permission Warnings

#### **Problem Description**
Netplan configuration files generated security warnings about world-readable permissions.

#### **Symptoms**
```bash
sudo netplan apply
# Warning: netplan config files are world readable
```

#### **Solution Implementation**
```bash
# Fix file permissions for all Netplan files
sudo chmod 600 /etc/netplan/*.yaml

# Verify permissions
ls -la /etc/netplan/
# Expected: -rw------- (600 permissions)
```

---

## 🔐 SSH & Authentication Issues

### Issue 3: SSH Host Key Verification Failures

#### **Problem Description**
Ansible controller unable to connect to itself (`192.168.10.2`) due to host key verification failures.

#### **Symptoms**
```bash
ssh nantwi@192.168.10.2
# Host key verification failed
```

#### **Root Cause**
First SSH connection to the controller's own IP address requires host key acceptance, which wasn't performed during initial setup.

#### **Solution Process**
```bash
# Interactive SSH connection to accept host key
ssh nantwi@192.168.10.2
# Prompt: "Are you sure you want to continue connecting (yes/no)?"
# Response: yes
# Result: Host key added to ~/.ssh/known_hosts
```

---

### Issue 4: SSH Key Distribution Process

#### **Implementation Process**
```bash
# Generate modern SSH key
ssh-keygen -t ed25519 -C "ansible-controller@lab-infrastructure"

# Distribute to each system individually
ssh-copy-id -i ~/.ssh/id_ed25519.pub nantwi@192.168.10.2  # Controller
ssh-copy-id -i ~/.ssh/id_ed25519.pub nantwi@192.168.20.2  # Wazuh
ssh-copy-id -i ~/.ssh/id_ed25519.pub nantwi@192.168.60.2  # Monitoring

# Verify passwordless access
ssh nantwi@192.168.10.2
ssh nantwi@192.168.20.2
ssh nantwi@192.168.60.2

# Test Ansible connectivity
ansible all_in_one -m ping
```

---

## 💾 Service & Package Management

### Issue 5: Rocky Linux Package Installation Conflicts

#### **Problem Description**
Previous Wazuh installation attempts on Rocky Linux created package conflicts, preventing clean installation of the latest version.

#### **Symptoms**
- Package installation failures
- Configuration file conflicts
- Service startup issues

#### **Solution Implementation**
```bash
# Remove all Wazuh-related packages
sudo dnf remove -y wazuh-* filebeat opensearch-dashboard

# Clean configuration and data directories
sudo rm -rf /etc/wazuh-* 
sudo rm -rf /var/lib/wazuh-* 
sudo rm -rf /usr/share/wazuh-* 
sudo rm -rf /etc/filebeat 
sudo rm -rf /var/lib/filebeat

# Clean package cache
sudo dnf clean all

# Proceed with fresh installation
curl -sO https://packages.wazuh.com/4.12/wazuh-install.sh
chmod +x wazuh-install.sh
sudo ./wazuh-install.sh -a -i -o
```

---

### Issue 6: Firewall Port Configuration for Services

#### **Problem Description**
Newly installed services (Wazuh, Grafana, Prometheus) inaccessible from other network segments due to firewall restrictions.

#### **Solution by Operating System**

##### Rocky Linux (Wazuh Server)
```bash
# Open Wazuh ports
sudo firewall-cmd --permanent --add-port=1514/tcp  # Agent communication
sudo firewall-cmd --permanent --add-port=1514/udp  # Agent communication
sudo firewall-cmd --permanent --add-port=1515/tcp  # Agent enrollment
sudo firewall-cmd --permanent --add-port=443/tcp   # HTTPS dashboard

# Apply changes
sudo firewall-cmd --reload

# Verify rules
sudo firewall-cmd --list-ports
```

##### Ubuntu (Monitoring Server)
```bash
# Ubuntu UFW configuration (if enabled)
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 22/tcp    # SSH

# Verify status
sudo ufw status
```

---

### Issue 7: Service Startup and Persistence

#### **Problem Description**
Some services failed to start automatically after system restart, requiring manual intervention.

#### **Solution Implementation**
```bash
# Enable services to start at boot
sudo systemctl enable wazuh-manager
sudo systemctl enable wazuh-indexer  
sudo systemctl enable wazuh-dashboard
sudo systemctl enable filebeat
sudo systemctl enable grafana-server
sudo systemctl enable prometheus
sudo systemctl enable ssh

# Check service status
sudo systemctl status [service-name]

# View service logs
sudo journalctl -u [service-name] -f
```

---

## 🔍 Common Diagnostic Commands

### Service Management
```bash
# Check service status
sudo systemctl status [service-name]

# Start/stop/restart services
sudo systemctl restart [service-name]

# View service logs
sudo journalctl -u [service-name] -f
```

### Network Configuration
```bash
# Check network interfaces
ip addr show

# Test connectivity
ping 192.168.10.1
ping 8.8.8.8

# Apply network configuration
sudo netplan apply
```

### SSH Troubleshooting
```bash
# Test SSH connectivity
ssh [user]@[host]

# Copy SSH keys
ssh-copy-id [user]@[host]

# Check SSH service
sudo systemctl status ssh
```

---

*System Administration Troubleshooting | Based on Real Implementation Issues*