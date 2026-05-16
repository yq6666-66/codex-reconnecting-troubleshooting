[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [int[]]$CommonHttpPorts = @(7897, 7890, 10809, 2080, 8080, 8888),
    [int[]]$CommonSocksPorts = @(7898, 7891, 10808, 1080, 2081),
    [string[]]$Domains = @("api.openai.com", "chatgpt.com"),
    [int]$CurlTimeoutSeconds = 12,
    [switch]$SkipDirectTcp
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
    } elseif ($Value -match "(^|;)socks=([^;]+)") {
        $Value = "socks5h://$($Matches[2])"
    }
    if ($Value -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        return "http://$Value"
    }
    return $Value
}

function New-ProxyCandidates {
    param(
        [int[]]$HttpPorts,
        [int[]]$SocksPorts
    )

    $items = @()
    foreach ($port in ($HttpPorts | Select-Object -Unique)) {
        $items += [PSCustomObject]@{
            Url = "http://127.0.0.1:$port"
            Kind = "HTTP"
            Port = $port
        }
    }
    foreach ($port in ($SocksPorts | Select-Object -Unique)) {
        $items += [PSCustomObject]@{
            Url = "socks5h://127.0.0.1:$port"
            Kind = "SOCKS5"
            Port = $port
        }
    }
    return $items
}

function Test-TcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 700
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait($TimeoutMilliseconds)) {
            return $false
        }
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
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
$portResults = foreach ($candidate in (New-ProxyCandidates -HttpPorts $CommonHttpPorts -SocksPorts $CommonSocksPorts)) {
    $port = $candidate.Port
    [PSCustomObject]@{
        Host = "127.0.0.1"
        Port = $port
        Kind = $candidate.Kind
        ProxyUrl = $candidate.Url
        TcpTestSucceeded = (Test-TcpPort -HostName "127.0.0.1" -Port $port)
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
if ($SkipDirectTcp) {
    Write-Host "Skipped. Direct TCP tests can be slow on restricted networks."
} else {
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
}

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
        curl.exe -sS -I --max-time $CurlTimeoutSeconds -x $ProxyUrl $url
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

Write-Section "Possible TUN Adapters"
$tunAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "tun|meta|mihomo|clash" -or
        $_.InterfaceDescription -match "tun|meta|mihomo|clash"
    } |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress

if ($tunAdapters) {
    $tunAdapters | Format-Table -AutoSize
} else {
    Write-Host "No obvious TUN adapter was found. This is normal if TUN mode is off."
}

Write-Section "Interpretation"
Write-Host "If direct TCP fails but proxy HTTPS returns 401 from api.openai.com, the proxy path is working and Codex should be forced to use it."
Write-Host "If proxy HTTPS also fails or TLS handshakes fail repeatedly, switch proxy nodes or enable TUN mode in your proxy client."
