# Beshkan - Windows DNS Switcher
# Requires: PowerShell 5.1+ and Administrator privileges

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Status
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

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
    Write-Host "  0) Reset to Default DNS    6) Cloudflare"
    Write-Host "  1) Shecan                  7) 403"
    Write-Host "  2) Electro                 8) Radar"
    Write-Host "  3) Begzar                  9) Shelter"
    Write-Host "  4) DNS Pro                10) Pishgaman"
    Write-Host "  5) Google                 11) Shatel"
    Write-Host ""
    Write-Host "Requires:" -ForegroundColor Yellow
    Write-Host "  - PowerShell 5.1 or later"
    Write-Host "  - Administrator privileges (right-click > Run as Administrator)"
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
    Write-Host "`nChoose a DNS Provider:" -ForegroundColor Cyan
    Write-Host "  0)  Reset to Default DNS"
    Write-Host "  1)  Shecan"
    Write-Host "  2)  Electro"
    Write-Host "  3)  Begzar"
    Write-Host "  4)  DNS Pro"
    Write-Host "  5)  Google"
    Write-Host "  6)  Cloudflare"
    Write-Host "  7)  403"
    Write-Host "  8)  Radar"
    Write-Host "  9)  Shelter"
    Write-Host "  10) Pishgaman"
    Write-Host "  11) Shatel"
    Write-Host ""
    $script:choice = Read-Host "Enter the number of the desired DNS"
}

function Apply-Dns {
    $dnsMap = @{
        "1"  = @{ Name = "Shecan";    Servers = @("178.22.122.100", "185.51.200.2") }
        "2"  = @{ Name = "Electro";   Servers = @("78.157.42.100", "78.157.42.101") }
        "3"  = @{ Name = "Begzar";    Servers = @("185.55.226.26", "185.55.226.25") }
        "4"  = @{ Name = "DNS Pro";   Servers = @("87.107.110.109", "87.107.110.110") }
        "5"  = @{ Name = "Google";    Servers = @("8.8.8.8", "8.8.4.4") }
        "6"  = @{ Name = "Cloudflare"; Servers = @("1.1.1.1", "1.0.0.1") }
        "7"  = @{ Name = "403";       Servers = @("10.202.10.202", "10.202.10.102") }
        "8"  = @{ Name = "Radar";     Servers = @("10.202.10.10", "10.202.10.11") }
        "9"  = @{ Name = "Shelter";   Servers = @("94.103.125.157", "94.103.125.158") }
        "10" = @{ Name = "Pishgaman"; Servers = @("5.202.100.100", "5.202.100.101") }
        "11" = @{ Name = "Shatel";    Servers = @("85.15.1.14", "85.15.1.15") }
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
                $dns = $dnsMap[$choice]
                if (-not $dns) {
                    Write-Host "Invalid selection" -ForegroundColor Red
                    exit 1
                }
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dns.Servers
                Write-Host "Set to $($dns.Name)" -ForegroundColor Green
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

# Check admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    exit 1
}

# Handle parameters
if ($Help) { Show-Help; exit 0 }
if ($Version) { Show-Version; exit 0 }
if ($Status) { Show-Status; exit 0 }

# Interactive mode
Select-Dns
Apply-Dns
