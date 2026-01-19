# Pre-Bootstrap Configuration Script for Windows Systems
# This script prepares a Windows system for Ansible automation
# Run as Administrator on target Windows system

param(
    [switch]$Verbose = $false,
    [switch]$SkipFirewall = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "=== Windows Pre-Bootstrap Configuration ===" -ForegroundColor Green
Write-Host "Preparing Windows server for Ansible automation..." -ForegroundColor Cyan
Write-Host ""

try {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✓ Running with Administrator privileges" -ForegroundColor Green
    Write-Host ""

    # Step 1: Enable PowerShell Remoting
    Write-Host "1. Enabling PowerShell Remoting..." -ForegroundColor Cyan
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
        Write-Host "   ✓ PowerShell Remoting enabled successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "   ⚠️  PowerShell Remoting may already be enabled" -ForegroundColor Yellow
    }
    
    # Step 2: Configure WinRM for basic authentication
    Write-Host "2. Configuring WinRM authentication..." -ForegroundColor Cyan
    
    # Set basic authentication
    & winrm set winrm/config/service/auth '@{Basic="true"}' | Out-Null
    Write-Host "   ✓ Basic authentication enabled" -ForegroundColor Green
    
    # Allow unencrypted communication (for lab environment)
    & winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
    Write-Host "   ✓ Unencrypted communication enabled (lab environment)" -ForegroundColor Green
    
    # Configure WinRM service settings
    & winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}' | Out-Null
    Write-Host "   ✓ WinRM memory limits configured" -ForegroundColor Green
    
    # Step 3: Configure Windows Firewall (unless skipped)
    if (-not $SkipFirewall) {
        Write-Host "3. Configuring Windows Firewall..." -ForegroundColor Cyan
        
        # Check if rule already exists
        $existingRule = Get-NetFirewallRule -DisplayName "WinRM-HTTP-In" -ErrorAction SilentlyContinue
        
        if (-not $existingRule) {
            $firewallRule = New-NetFirewallRule -DisplayName "WinRM-HTTP-In" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
            Write-Host "   ✓ Firewall rule created for WinRM HTTP (port 5985)" -ForegroundColor Green
        } else {
            Write-Host "   ✓ Firewall rule already exists for WinRM HTTP" -ForegroundColor Yellow
        }
        
        # Optional: Add HTTPS rule for future use
        $existingHTTPSRule = Get-NetFirewallRule -DisplayName "WinRM-HTTPS-In" -ErrorAction SilentlyContinue
        if (-not $existingHTTPSRule) {
            $httpsRule = New-NetFirewallRule -DisplayName "WinRM-HTTPS-In" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
            Write-Host "   ✓ Firewall rule created for WinRM HTTPS (port 5986)" -ForegroundColor Green
        } else {
            Write-Host "   ✓ Firewall rule already exists for WinRM HTTPS" -ForegroundColor Yellow
        }
    } else {
        Write-Host "3. Skipping Windows Firewall configuration..." -ForegroundColor Yellow
    }
    
    # Step 4: Verify WinRM configuration
    Write-Host "4. Verifying WinRM configuration..." -ForegroundColor Cyan
    
    # Test WinRM locally
    try {
        $wsmanTest = Test-WSMan localhost -ErrorAction Stop
        Write-Host "   ✓ WinRM is responding locally" -ForegroundColor Green
        
        if ($Verbose) {
            Write-Host "   Protocol Version: $($wsmanTest.ProtocolVersion)" -ForegroundColor Gray
            Write-Host "   Product Vendor: $($wsmanTest.ProductVendor)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   ❌ WinRM verification failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    # Check WinRM listeners
    Write-Host "   ✓ Checking WinRM listeners..." -ForegroundColor Gray
    $listeners = & winrm enumerate winrm/config/listener
    if ($listeners -match "Address = \*" -and $listeners -match "Port = 5985") {
        Write-Host "   ✓ WinRM HTTP listener configured correctly" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  WinRM listener configuration may need attention" -ForegroundColor Yellow
    }
    
    # Step 5: Display system and connection information
    Write-Host "5. System Information:" -ForegroundColor Cyan
    
    $computerInfo = Get-ComputerInfo -Property CsName, WindowsProductName, WindowsVersion, CsDomain, TotalPhysicalMemory
    $ipAddresses = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike "127.*" -and 
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notlike "*Loopback*"
    }).IPAddress
    
    Write-Host "   Computer Name: $($computerInfo.CsName)" -ForegroundColor Yellow
    Write-Host "   Operating System: $($computerInfo.WindowsProductName)" -ForegroundColor Yellow
    Write-Host "   Version: $($computerInfo.WindowsVersion)" -ForegroundColor Yellow
    Write-Host "   Domain/Workgroup: $($computerInfo.CsDomain)" -ForegroundColor Yellow
    Write-Host "   Total Memory: $([math]::Round($computerInfo.TotalPhysicalMemory/1GB,2)) GB" -ForegroundColor Yellow
    Write-Host "   IP Addresses: $($ipAddresses -join ', ')" -ForegroundColor Yellow
    Write-Host "   WinRM HTTP Port: 5985" -ForegroundColor Yellow
    Write-Host "   WinRM HTTPS Port: 5986" -ForegroundColor Yellow
    
    # Step 6: Security and service information
    Write-Host "6. Security Configuration:" -ForegroundColor Cyan
    
    # Check WinRM service status
    $winrmService = Get-Service WinRM
    Write-Host "   WinRM Service Status: $($winrmService.Status)" -ForegroundColor $(if($winrmService.Status -eq "Running") {"Green"} else {"Red"})
    
    # Check Windows Firewall status
    $firewallProfiles = Get-NetFirewallProfile
    foreach ($profile in $firewallProfiles) {
        $status = if ($profile.Enabled) { "Enabled" } else { "Disabled" }
        $color = if ($profile.Enabled) { "Green" } else { "Yellow" }
        Write-Host "   Firewall ($($profile.Name)): $status" -ForegroundColor $color
    }
    
    # Check current user context
    Write-Host "   Current User: $($currentUser.Name)" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "=== Pre-Bootstrap Configuration Complete ===" -ForegroundColor Green
    Write-Host "✅ This Windows system is now ready for Ansible bootstrap!" -ForegroundColor Green
    
    # Step 7: Display next steps
    if ($Verbose -or $true) {  # Always show next steps
        Write-Host ""
        Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. From your Ansible Controller (192.168.10.2), test connectivity:" -ForegroundColor White
        Write-Host "   ansible $($ipAddresses[0]) -m win_ping \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_user=Administrator`" \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_password=YourAdminPassword`" \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_connection=winrm`" \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_winrm_transport=basic`" \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_port=5985`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. If connectivity test succeeds, run the bootstrap playbook:" -ForegroundColor White
        Write-Host "   ansible-playbook bootstrap_windows.yml \" -ForegroundColor Gray
        Write-Host "     -e `"target_host=$($ipAddresses[0])`" \" -ForegroundColor Gray
        Write-Host "     -e `"initial_user=Administrator`" \" -ForegroundColor Gray
        Write-Host "     -e `"initial_password=YourAdminPassword`" \" -ForegroundColor Gray
        Write-Host "     -e `"ansible_service_password=Password123`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. After bootstrap, the system will be fully managed by Ansible" -ForegroundColor White
        Write-Host ""
        
        # Additional troubleshooting information
        Write-Host "💡 Troubleshooting Tips:" -ForegroundColor Cyan
        Write-Host "   • If connection fails, verify the Administrator password" -ForegroundColor Gray
        Write-Host "   • Ensure the Ansible Controller can reach this IP: $($ipAddresses[0])" -ForegroundColor Gray
        Write-Host "   • Check Windows Firewall if connection times out" -ForegroundColor Gray
        Write-Host "   • Verify this system is in the correct VLAN (Management VLAN preferred)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Create a completion marker file
    $markerPath = "C:\temp\pre-bootstrap-complete.txt"
    $null = New-Item -Path "C:\temp" -ItemType Directory -Force -ErrorAction SilentlyContinue
    $completionInfo = @"
Pre-Bootstrap Completion Report
===============================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $($computerInfo.CsName)
IP Addresses: $($ipAddresses -join ', ')
OS: $($computerInfo.WindowsProductName)
Domain: $($computerInfo.CsDomain)

Configuration Applied:
- PowerShell Remoting: Enabled
- WinRM Basic Auth: Enabled
- WinRM Unencrypted: Enabled (lab environment)
- Firewall HTTP (5985): Configured
- Firewall HTTPS (5986): Configured
- WinRM Service: $($winrmService.Status)

Ready for Ansible bootstrap: YES

Next: Run bootstrap playbook from Ansible Controller
"@
    
    $completionInfo | Out-File -FilePath $markerPath -Encoding UTF8
    Write-Host "📄 Completion report saved to: $markerPath" -ForegroundColor Gray
    
}
    Write-Host "• Ensure you're running PowerShell as Administrator" -ForegroundColor Gray
    Write-Host "• Check if WinRM service is installed and can be started" -ForegroundColor Gray
    Write-Host "• Verify Windows Firewall is not blocking the configuration" -ForegroundColor Gray
    Write-Host "• Try running: Enable-PSRemoting -Force" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Additional helper functions for advanced users
function Show-WinRMConfiguration {
    Write-Host "Current WinRM Configuration:" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    try {
        Write-Host "Service Configuration:" -ForegroundColor Yellow
        & winrm get winrm/config/service
        
        Write-Host "`nClient Configuration:" -ForegroundColor Yellow
        & winrm get winrm/config/client
        
        Write-Host "`nListeners:" -ForegroundColor Yellow
        & winrm enumerate winrm/config/listener
    }
    catch {
        Write-Host "Unable to retrieve WinRM configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-AnsibleConnectivity {
    param(
        [string]$AnsibleControllerIP = "192.168.10.2"
    )
    
    Write-Host "Testing connectivity to Ansible Controller..." -ForegroundColor Cyan
    
    # Test basic network connectivity
    if (Test-Connection -ComputerName $AnsibleControllerIP -Count 2 -Quiet) {
        Write-Host "✓ Network connectivity to $AnsibleControllerIP successful" -ForegroundColor Green
    } else {
        Write-Host "❌ Cannot reach Ansible Controller at $AnsibleControllerIP" -ForegroundColor Red
        return $false
    }
    
    # Test if port 22 (SSH) is accessible on controller
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = 3000
        $tcpClient.SendTimeout = 3000
        $tcpClient.Connect($AnsibleControllerIP, 22)
        $tcpClient.Close()
        Write-Host "✓ SSH port (22) accessible on Ansible Controller" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠️  SSH port (22) not accessible on Ansible Controller" -ForegroundColor Yellow
        Write-Host "   This may be normal if SSH is configured differently" -ForegroundColor Gray
        return $true  # Don't fail on this
    }
}

# Show additional help if verbose mode is enabled
if ($Verbose) {
    Write-Host ""
    Write-Host "🔧 Advanced Options Available:" -ForegroundColor Cyan
    Write-Host "• Run with -SkipFirewall to skip Windows Firewall configuration" -ForegroundColor Gray
    Write-Host "• Use Show-WinRMConfiguration function to view detailed WinRM settings" -ForegroundColor Gray
    Write-Host "• Use Test-AnsibleConnectivity function to test connection to controller" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example usage:" -ForegroundColor Gray
    Write-Host "  .\pre-bootstrap.ps1 -Verbose -SkipFirewall" -ForegroundColor Gray
    Write-Host "  Show-WinRMConfiguration" -ForegroundColor Gray
    Write-Host "  Test-AnsibleConnectivity -AnsibleControllerIP 192.168.10.2" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🎯 Pre-Bootstrap Status: READY FOR ANSIBLE AUTOMATION" -ForegroundColor Green -BackgroundColor DarkGreen
Write-Host ""