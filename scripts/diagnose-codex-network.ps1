[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [int[]]$CommonProxyPorts = @(7897, 7890, 10809, 1080),
    [string[]]$Domains = @("api.openai.com", "chatgpt.com")
)

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "== $Title =="
}

function Get-ProxyUri {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    if ($Value -match "(^|;)https=([^;]+)") {
        $Value = $Matches[2]
    } elseif ($Value -match "(^|;)http=([^;]+)") {
        $Value = $Matches[2]
    }
    if ($Value -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        return "http://$Value"
    }
    return $Value
}

Write-Section "Windows System Proxy"
$internetSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
$internetSettings | Select-Object ProxyEnable, ProxyServer, AutoConfigURL | Format-List

Write-Section "User Proxy Environment Variables"
Get-ItemProperty -Path "HKCU:\Environment" -ErrorAction SilentlyContinue |
    Select-Object HTTP_PROXY, HTTPS_PROXY, ALL_PROXY, NO_PROXY |
    Format-List

Write-Section "Current Process Proxy Environment Variables"
$envNames = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy") | Select-Object -Unique
$envResults = foreach ($name in $envNames) {
    $value = [Environment]::GetEnvironmentVariable($name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        [PSCustomObject]@{
            Name = $name
            Value = $value
        }
    }
}
$envResults | Format-Table -AutoSize

Write-Section "Common Local Proxy Ports"
$portResults = foreach ($port in $CommonProxyPorts) {
    $result = Test-NetConnection 127.0.0.1 -Port $port -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Host = "127.0.0.1"
        Port = $port
        TcpTestSucceeded = $result.TcpTestSucceeded
    }
}
$portResults | Format-Table -AutoSize

Write-Section "DNS Resolution"
foreach ($domain in $Domains) {
    Write-Host "-- $domain"
    Resolve-DnsName $domain -ErrorAction SilentlyContinue |
        Select-Object Name, Type, IPAddress, NameHost |
        Format-Table -AutoSize
}

Write-Section "Direct TCP Connectivity"
$directResults = foreach ($domain in $Domains) {
    $result = Test-NetConnection $domain -Port 443 -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Domain = $domain
        RemoteAddress = $result.RemoteAddress
        TcpTestSucceeded = $result.TcpTestSucceeded
        PingSucceeded = $result.PingSucceeded
    }
}
$directResults | Format-Table -AutoSize

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    $ProxyUrl = Get-ProxyUri $internetSettings.ProxyServer
}
$ProxyUrl = Get-ProxyUri $ProxyUrl

Write-Section "Proxy HTTPS Test"
if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    Write-Host "No proxy URL was provided and no Windows proxy server was found."
} else {
    Write-Host "Using proxy: $ProxyUrl"
    foreach ($url in @("https://api.openai.com/v1/models", "https://chatgpt.com")) {
        Write-Host "-- $url"
        curl.exe -sS -I --max-time 20 -x $ProxyUrl $url
    }
}

Write-Section "Codex Processes"
$codex = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "^Codex$|^codex$" }
$codex | Select-Object ProcessName, Id, Path | Format-Table -AutoSize

Write-Section "Codex TCP Connections"
if ($codex) {
    $ids = $codex.Id
    Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object { $ids -contains $_.OwningProcess } |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess |
        Sort-Object OwningProcess, RemoteAddress, RemotePort |
        Format-Table -AutoSize
} else {
    Write-Host "No Codex process is running."
}

Write-Section "Interpretation"
Write-Host "If direct TCP fails but proxy HTTPS returns 401 from api.openai.com, the proxy path is working and Codex should be forced to use it."
Write-Host "If proxy HTTPS also fails or TLS handshakes fail repeatedly, switch proxy nodes or enable TUN mode in your proxy client."
