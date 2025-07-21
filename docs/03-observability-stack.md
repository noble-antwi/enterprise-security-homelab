# Observability Stack & Monitoring Infrastructure

## 📖 Overview

This document details the deployment and configuration of the **observability and monitoring infrastructure** using **Grafana** and **Prometheus** on a dedicated Ubuntu Server 24.04 system. The monitoring stack is strategically deployed within the **Monitoring VLAN (VLAN 60)** to provide centralized visibility into the entire lab infrastructure while maintaining network segmentation and security isolation.

## 🎯 Deployment Objectives

### Primary Goals
- Establish comprehensive infrastructure monitoring capabilities
- Deploy Grafana for visualization and dashboarding
- Implement Prometheus for metrics collection and storage
- Create foundation for observability across all lab VLANs
- Provide centralized monitoring without network interference

### Strategic Architecture
- **VLAN Assignment**: Monitoring VLAN (VLAN 60 - `192.168.60.0/24`)
- **Network Isolation**: Dedicated monitoring segment separated from operational systems
- **Centralized Approach**: Single monitoring stack serving entire lab infrastructure
- **Scalable Design**: Foundation for future monitoring expansion

## 🖥️ Server Deployment & Network Configuration

### Hardware & System Specifications
| Component | Details |
|-----------|---------|
| **Hostname** | `nbl-core-ub01` |
| **Operating System** | Ubuntu 24.04 LTS Server |
| **Architecture** | x86_64 |
| **Network Interface** | Primary ethernet interface |
| **Switch Connection** | Port 8 (Untagged VLAN 60) |
| **Physical Location** | Dedicated standalone system |

### Network Configuration Strategy

#### Switch Port Assignment
- **Physical Port**: Port 8 on TP-Link TL-SG108E managed switch
- **VLAN Configuration**: Untagged member of VLAN 60 (Monitoring)
- **Network Segment**: `192.168.60.0/24` subnet
- **Gateway Assignment**: `192.168.60.1` (pfSense)

#### Static IP Implementation
For consistent monitoring service accessibility, a static IP configuration was implemented:

**Target Network Configuration:**
| Parameter | Value |
|-----------|-------|
| **IP Address** | `192.168.60.2/24` |
| **Gateway** | `192.168.60.1` |
| **DNS Servers** | `8.8.8.8`, `8.8.4.4`, `1.1.1.1` |
| **Network Interface** | Primary ethernet |

#### Network Configuration Process
Ubuntu 24.04 Server uses Netplan for network configuration management:

```yaml
# /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    [interface-name]:
      addresses:
        - 192.168.60.2/24
      routes:
        - to: 0.0.0.0/0
          via: 192.168.60.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
          - 1.1.1.1
```

#### Network Configuration Evidence
![Network Configuration for Ubuntu Server](image-8.png)

#### Connectivity Verification
```bash
# Test gateway connectivity
ping -c 4 192.168.60.1

# Verify external connectivity  
ping -c 4 8.8.8.8

# Confirm DNS resolution
nslookup google.com
```

**Verification Results:**
✅ **Gateway Connectivity**: Successfully reached `192.168.60.1`  
✅ **Internet Access**: External connectivity confirmed via outbound NAT  
✅ **DNS Resolution**: Name resolution functional  
✅ **VLAN Assignment**: Confirmed placement in Monitoring VLAN  

## 🔐 Inter-VLAN Access Configuration

### pfSense Firewall Rule Implementation
To enable administrative access from the Management VLAN and proper monitoring functionality, specific firewall rules were configured on pfSense.

#### Management to Monitoring VLAN Access
**Rule Purpose**: Allow administrative access to monitoring systems from Management VLAN

**Firewall Rule Configuration:**
- **Source**: Management VLAN subnet (`192.168.10.0/24`)
- **Destination**: Monitoring VLAN subnet (`192.168.60.0/24`)
- **Action**: Allow
- **Protocol**: Any
- **Purpose**: Administrative access and monitoring management

#### Monitoring to Management VLAN Access  
**Rule Purpose**: Enable monitoring systems to collect metrics from Management VLAN resources

**Firewall Rule Configuration:**
- **Source**: Monitoring VLAN subnet (`192.168.60.0/24`)
- **Destination**: Management VLAN subnet (`192.168.10.0/24`)
- **Action**: Allow
- **Protocol**: Any
- **Purpose**: Metrics collection and system monitoring

#### Outbound Internet Access
Both VLANs maintain their ability to reach external resources for updates, package downloads, and external monitoring targets.

#### Access Validation
```bash
# From Management VLAN (192.168.10.2) - test SSH access to monitoring server
ssh nantwi@192.168.60.2

# From Monitoring VLAN - test connectivity to Management systems
ping 192.168.10.1  # pfSense gateway
ping 192.168.10.2  # Ansible controller
```

**Results**: ✅ Bidirectional connectivity established and verified

## 📊 Grafana Deployment & Configuration

### Installation Process
Grafana was installed using the official repository method for Ubuntu systems:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y software-properties-common wget

# Add Grafana GPG key
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# Add Grafana repository
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Update package list and install Grafana
sudo apt update
sudo apt install -y grafana
```

### Service Configuration
```bash
# Enable Grafana service for automatic startup
sudo systemctl enable grafana-server

# Start Grafana service
sudo systemctl start grafana-server

# Verify service status
sudo systemctl status grafana-server
```

### Grafana Access Configuration
**Service Details:**
- **Port**: 3000 (default Grafana port)
- **Protocol**: HTTP (HTTPS can be configured later)
- **Access URL**: `http://192.168.60.2:3000`
- **Default Credentials**: admin/admin (changed on first login)

#### Grafana Dashboard Access
![Grafana Dashboard - Initial Access](image-9.png)

### Initial Configuration Validation
✅ **Service Status**: Grafana-server active and running  
✅ **Network Accessibility**: Dashboard accessible from Management VLAN  
✅ **Web Interface**: Grafana UI responsive and functional  
✅ **Authentication**: Login process working correctly  

## 🔍 Prometheus Deployment & Configuration

### Installation Process
Prometheus was installed using the Ubuntu package manager:

```bash
# Install Prometheus from Ubuntu repositories
sudo apt install -y prometheus

# Verify installation
prometheus --version
```

### Service Configuration  
```bash
# Enable Prometheus service
sudo systemctl enable prometheus

# Start Prometheus service  
sudo systemctl start prometheus

# Verify service status
sudo systemctl status prometheus
```

### Prometheus Access Configuration
**Service Details:**
- **Port**: 9090 (default Prometheus port)
- **Protocol**: HTTP
- **Access URL**: `http://192.168.60.2:9090`
- **Configuration**: Default configuration with local metrics

#### Prometheus Interface Access
![Prometheus Dashboard - Initial Access](image-10.png)

### Default Configuration Status
- **Data Collection**: Self-monitoring metrics operational
- **Storage**: Local time-series database functional
- **Query Interface**: PromQL query interface accessible
- **API Endpoints**: REST API available for integrations

## 🛠️ System Integration & Accessibility

### SSH Administrative Access
SSH access was configured for remote administration and maintenance:

```bash
# Ensure SSH service is installed and running
sudo systemctl status ssh

# Test SSH connectivity from Management VLAN
ssh nantwi@192.168.60.2
```

**SSH Access Verification:**
✅ **Service Status**: SSH daemon active and listening  
✅ **Network Access**: SSH accessible from Management VLAN  
✅ **Authentication**: Key-based and password authentication functional  
✅ **Security**: SSH access controlled by pfSense firewall rules  

### Service Port Summary
| Service | Port | Protocol | Access URL | Status |
|---------|------|----------|------------|--------|
| **Grafana** | 3000 | HTTP | `http://192.168.60.2:3000` | 🟢 Active |
| **Prometheus** | 9090 | HTTP | `http://192.168.60.2:9090` | 🟢 Active |
| **SSH** | 22 | TCP | `ssh nantwi@192.168.60.2` | 🟢 Active |

## 🔧 Current Monitoring Capabilities

### Grafana Features Available
- **Dashboard Creation**: Visual dashboard development environment
- **Data Source Integration**: Ready for Prometheus and other data sources
- **User Management**: Authentication and authorization system
- **Alerting Framework**: Alert rule configuration capabilities
- **Plugin System**: Extensible with community and commercial plugins

### Prometheus Capabilities
- **Metrics Collection**: Time-series data collection and storage
- **Query Language**: PromQL for metric analysis and aggregation
- **Data Retention**: Configurable retention policies
- **API Access**: RESTful API for external integrations
- **Service Discovery**: Automatic target discovery mechanisms

### Current Monitoring Scope
- **Self-Monitoring**: Both services monitoring themselves
- **System Metrics**: Basic host-level metrics collection
- **Network Connectivity**: Network reachability monitoring
- **Service Health**: Application and service status monitoring

## 🚀 Integration Framework

### Prepared for Expansion
The monitoring infrastructure is architected to support:

#### Data Source Integration
- **Additional Prometheus Instances**: Multiple Prometheus servers for different VLANs
- **Log Aggregation**: Integration with log management systems (Loki, ELK)
- **Database Monitoring**: MySQL, PostgreSQL, MongoDB metrics
- **Application Metrics**: Custom application monitoring

#### Exporter Integration
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **Blackbox Exporter**: Network endpoint monitoring and availability
- **SNMP Exporter**: Network device monitoring (switches, routers)
- **Custom Exporters**: Application-specific metrics collection

#### External Monitoring
- **Wazuh Integration**: Security metrics and log analysis
- **pfSense Monitoring**: Firewall and network performance metrics
- **Infrastructure Monitoring**: VM and container metrics
- **Service Monitoring**: Application availability and performance

## 🔐 Security Implementation

### Network Security
- **VLAN Isolation**: Monitoring systems contained within dedicated VLAN
- **Firewall Controls**: pfSense manages all inter-VLAN communication
- **Access Restrictions**: Administrative access limited to Management VLAN
- **Service Exposure**: Monitoring interfaces not exposed to internet

### Authentication & Access Control
- **Grafana Authentication**: Default admin credentials changed on deployment
- **SSH Access**: Public key authentication configured
- **Service Security**: Services running with appropriate user permissions
- **Network Filtering**: pfSense firewall rules control access patterns

## 📈 Performance & Scalability

### Current Resource Utilization
- **CPU Usage**: Minimal load during idle state
- **Memory Consumption**: Efficient resource utilization
- **Storage Requirements**: Adequate space for metrics retention
- **Network Bandwidth**: Low bandwidth requirements for current monitoring scope

### Scalability Considerations
- **Data Retention**: Configurable retention policies for storage management
- **Query Performance**: Prometheus optimized for time-series queries
- **Dashboard Performance**: Grafana efficient for visualization rendering
- **High Availability**: Framework supports future HA implementation

## 🔄 Operational Status

### Service Health Monitoring
```bash
# Check all monitoring services
sudo systemctl status grafana-server prometheus ssh

# Verify network connectivity
ss -tlnp | grep -E ':(3000|9090|22)'

# Test web interfaces
curl -I http://192.168.60.2:3000  # Grafana health
curl -I http://192.168.60.2:9090  # Prometheus health
```

### Connectivity Matrix
| Source | Destination | Protocol | Status |
|--------|-------------|----------|--------|
| Management VLAN | Monitoring Server | HTTP/HTTPS | ✅ Accessible |
| Management VLAN | Monitoring Server | SSH | ✅ Accessible |
| Monitoring Server | Internet | HTTP/HTTPS | ✅ Accessible |
| Monitoring Server | Management VLAN | Various | ✅ Accessible |

## 🎯 Future Enhancement Pipeline

### Planned Integrations
- **Node Exporter Deployment**: System metrics across all VLANs
- **Prometheus Configuration**: Scraping targets for all lab infrastructure
- **Grafana Dashboard Development**: Custom dashboards for lab monitoring
- **Alerting Implementation**: Proactive monitoring alerts and notifications

### Advanced Monitoring Features
- **Log Aggregation**: Loki deployment for centralized logging
- **Distributed Tracing**: Application performance monitoring
- **Custom Metrics**: Application and service-specific monitoring
- **Compliance Monitoring**: Security and compliance metric tracking

## ✅ Deployment Validation

### Functional Testing Results
✅ **Grafana Accessibility**: Web interface responsive from Management VLAN  
✅ **Prometheus Functionality**: Query interface operational and responsive  
✅ **SSH Connectivity**: Remote administration access functional  
✅ **Inter-VLAN Communication**: Bidirectional network access verified  
✅ **Service Persistence**: All services survive system restart  

### Security Validation
✅ **VLAN Isolation**: Confirmed placement in Monitoring VLAN  
✅ **Firewall Rules**: Appropriate access controls implemented  
✅ **Service Security**: Services running with proper permissions  
✅ **Access Control**: Administrative access properly secured  

### Integration Verification  
✅ **Network Integration**: Proper integration with pfSense infrastructure  
✅ **DNS Resolution**: Name resolution functional across network  
✅ **Gateway Access**: Routing through pfSense operational  
✅ **Internet Connectivity**: External access for updates and integrations  

## 📋 Current Deployment Summary

### Successfully Implemented Components
| Component | Version | Status | Access Method |
|-----------|---------|--------|---------------|
| **Grafana** | Latest OSS | 🟢 Operational | `http://192.168.60.2:3000` |
| **Prometheus** | Latest Stable | 🟢 Operational | `http://192.168.60.2:9090` |
| **SSH Service** | OpenSSH | 🟢 Operational | `ssh nantwi@192.168.60.2` |
| **Network Config** | Static IP | 🟢 Operational | `192.168.60.2/24` |

### Infrastructure Integration Status
- **VLAN Assignment**: ✅ Successfully placed in Monitoring VLAN (60)
- **Network Connectivity**: ✅ Full connectivity with appropriate security controls
- **Administrative Access**: ✅ Management VLAN access configured and tested
- **Service Discovery**: ✅ Ready for monitoring target integration
- **Scalability Foundation**: ✅ Architecture supports future expansion

---

*Observability Stack Status: ✅ Complete and Operational*  
*Next Phase: [Automation Platform Deployment](04-automation-platform.md)*