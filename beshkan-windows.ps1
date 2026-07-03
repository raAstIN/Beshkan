# Beshkan - Windows DNS Switcher
# Requires: PowerShell 5.1+ and Administrator privileges

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Status
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$CustomDnsFile = Join-Path $HOME ".beshkan_dns"
$BuiltInDnsProviders = @(
    @{ Name = "Shecan";    Servers = @("178.22.122.100", "185.51.200.2") },
    @{ Name = "Electro";   Servers = @("78.157.42.100", "78.157.42.101") },
    @{ Name = "Begzar";    Servers = @("185.55.226.26", "185.55.226.25") },
    @{ Name = "DNS Pro";   Servers = @("87.107.110.109", "87.107.110.110") },
    @{ Name = "Google";    Servers = @("8.8.8.8", "8.8.4.4") },
    @{ Name = "Cloudflare"; Servers = @("1.1.1.1", "1.0.0.1") },
    @{ Name = "403";       Servers = @("10.202.10.202", "10.202.10.102") },
    @{ Name = "Radar";     Servers = @("10.202.10.10", "10.202.10.11") },
    @{ Name = "Shelter";   Servers = @("94.103.125.157", "94.103.125.158") },
    @{ Name = "Pishgaman"; Servers = @("5.202.100.100", "5.202.100.101") },
    @{ Name = "Shatel";    Servers = @("85.15.1.14", "85.15.1.15") }
)

function Show-Version {
    Write-Host "Beshkan" -ForegroundColor Cyan -NoNewline
    Write-Host " v$ScriptVersion"
    Write-Host "Windows DNS Switcher"
}

function Show-Help {
    Write-Host "Beshkan" -ForegroundColor Cyan -NoNewline
    Write-Host " - Fast DNS Switcher for Windows"
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\beshkan-windows.ps1              Launch interactive DNS selector"
    Write-Host "  .\beshkan-windows.ps1 -Status      Show current DNS settings"
    Write-Host "  .\beshkan-windows.ps1 -Version     Show version"
    Write-Host "  .\beshkan-windows.ps1 -Help        Show this help message"
    Write-Host ""
    Write-Host "Supported DNS Providers:" -ForegroundColor Yellow
    Write-Host "  0) Reset to Default DNS"
    Write-Host "  1-11) Built-in DNS providers"
    Write-Host "  a) Add a custom DNS provider"
    Write-Host ""
    Write-Host "Requires:" -ForegroundColor Yellow
    Write-Host "  - PowerShell 5.1 or later"
    Write-Host "  - Administrator privileges (right-click > Run as Administrator)"
}

function Test-IPv4Address {
    param([string]$Address)

    if ($Address -notmatch "^(\d{1,3}\.){3}\d{1,3}$") {
        return $false
    }

    foreach ($part in $Address.Split(".")) {
        $number = [int]$part
        if ($number -lt 0 -or $number -gt 255) {
            return $false
        }
    }

    return $true
}

function Get-CustomDnsProviders {
    $providers = @()
    if (-not (Test-Path $CustomDnsFile)) {
        return $providers
    }

    foreach ($line in Get-Content $CustomDnsFile) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split "\|", 3
        if ($parts.Count -eq 3) {
            $providers += @{ Name = $parts[0]; Servers = @($parts[1], $parts[2]) }
        }
    }

    return $providers
}

function Add-CustomDns {
    $title = (Read-Host "Title for this DNS provider").Replace("|", " ").Trim()
    $primary = Read-Host "Primary DNS address"
    $secondary = Read-Host "Secondary DNS address"

    if ([string]::IsNullOrWhiteSpace($title)) {
        Write-Host "Title cannot be empty." -ForegroundColor Red
        return $null
    }

    if (-not (Test-IPv4Address $primary) -or -not (Test-IPv4Address $secondary)) {
        Write-Host "Invalid IPv4 address." -ForegroundColor Red
        return $null
    }

    Add-Content -Path $CustomDnsFile -Value "$title|$primary|$secondary"
    Write-Host "Added $title to the end of the list." -ForegroundColor Green
    return @{ Name = $title; Servers = @($primary, $secondary) }
}

function Get-SelectedDns {
    param([string]$Selection)

    if ($Selection -eq "0") {
        return @{ Name = "Default"; Servers = @() }
    }

    $number = 0
    if (-not [int]::TryParse($Selection, [ref]$number)) {
        return $null
    }

    if ($number -ge 1 -and $number -le $BuiltInDnsProviders.Count) {
        return $BuiltInDnsProviders[$number - 1]
    }

    $customProviders = Get-CustomDnsProviders
    $customIndex = $number - $BuiltInDnsProviders.Count - 1
    if ($customIndex -ge 0 -and $customIndex -lt $customProviders.Count) {
        return $customProviders[$customIndex]
    }

    return $null
}

function Show-Status {
    Write-Host "`nCurrent DNS Settings:" -ForegroundColor Cyan
    Write-Host ""

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $dns = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).ServerAddresses
        $dnsDisplay = if ($dns.Count -gt 0) { $dns -join ", " } else { "DHCP" }
        Write-Host "  $($adapter.Name):" -ForegroundColor Yellow
        Write-Host "    $dnsDisplay" -ForegroundColor Green
    }
}

function Select-Dns {
    while ($true) {
        Write-Host "`nChoose a DNS Provider:" -ForegroundColor Cyan
        Write-Host "  0)  Reset to Default DNS"

        for ($i = 0; $i -lt $BuiltInDnsProviders.Count; $i++) {
            Write-Host ("  {0})  {1}" -f ($i + 1), $BuiltInDnsProviders[$i].Name)
        }

        $customProviders = Get-CustomDnsProviders
        for ($i = 0; $i -lt $customProviders.Count; $i++) {
            $number = $BuiltInDnsProviders.Count + $i + 1
            Write-Host ("  {0})  {1} ({2}, {3})" -f $number, $customProviders[$i].Name, $customProviders[$i].Servers[0], $customProviders[$i].Servers[1])
        }

        Write-Host "  a)  Add custom DNS"
        Write-Host ""
        $script:choice = Read-Host "Enter the number of the desired DNS"

        if ($script:choice -eq "a" -or $script:choice -eq "A") {
            $script:selectedDns = Add-CustomDns
            if ($script:selectedDns) {
                return
            }
        } else {
            $script:selectedDns = Get-SelectedDns $script:choice
            return
        }
    }
}

function Apply-Dns {
    if (-not $script:selectedDns) {
        Write-Host "Invalid selection" -ForegroundColor Red
        exit 1
    }
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    if ($adapters.Count -eq 0) {
        Write-Host "No active network adapters found." -ForegroundColor Red
        exit 1
    }

    Write-Host "`nApplying DNS settings..." -ForegroundColor Cyan
    Write-Host ""

    $success = 0
    $fail = 0

    foreach ($adapter in $adapters) {
        Write-Host "  $($adapter.Name): " -NoNewline
        try {
            if ($choice -eq "0") {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
                Write-Host "Reset to default" -ForegroundColor Green
                $success++
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $script:selectedDns.Servers
                Write-Host "Set to $($script:selectedDns.Name)" -ForegroundColor Green
                $success++
            }
        } catch {
            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
            $fail++
        }
    }

    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green -NoNewline
    Write-Host " $success adapter(s) updated, $fail failed."
}

# Handle parameters
if ($Help) { Show-Help; exit 0 }
if ($Version) { Show-Version; exit 0 }
if ($Status) { Show-Status; exit 0 }

# Check admin privileges before changing DNS settings
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    exit 1
}

# Interactive mode
Select-Dns
Apply-Dns
