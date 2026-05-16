[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [int[]]$CommonHttpPorts = @(7897, 7890, 10809, 10809, 2080, 8080, 8888),
    [int[]]$CommonSocksPorts = @(7898, 7891, 10808, 1080, 2081),
    [string]$NoProxy = "localhost,127.0.0.1,::1",
    [int]$CurlTimeoutSeconds = 12
)

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "== $Title =="
}

function Normalize-ProxyUrl {
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

function Test-ProxyUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    try {
        curl.exe -sS -I --max-time $CurlTimeoutSeconds -x $Url "https://api.openai.com/v1/models" | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

Write-Section "Step 1: Find Proxy"

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    $internetSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($internetSettings.ProxyEnable -eq 1) {
        $ProxyUrl = Normalize-ProxyUrl $internetSettings.ProxyServer
        if ($ProxyUrl) {
            Write-Host "Found Windows system proxy: $ProxyUrl"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    foreach ($candidate in (New-ProxyCandidates -HttpPorts $CommonHttpPorts -SocksPorts $CommonSocksPorts)) {
        if (Test-TcpPort -HostName "127.0.0.1" -Port $candidate.Port) {
            Write-Host "Found listening local $($candidate.Kind) proxy candidate: $($candidate.Url)"
            if (Test-ProxyUrl $candidate.Url) {
                $ProxyUrl = $candidate.Url
                Write-Host "Selected working proxy candidate: $ProxyUrl"
                break
            }
        }
    }
}

$ProxyUrl = Normalize-ProxyUrl $ProxyUrl

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    Write-Host "No proxy was found."
    Write-Host "Open your proxy app, enable system proxy, then rerun this script."
    Write-Host "Or specify it manually, for example:"
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"'
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "socks5h://127.0.0.1:10808"'
    exit 1
}

Write-Host "Selected proxy: $ProxyUrl"

Write-Section "Step 2: Test Proxy"
$proxyWorks = Test-ProxyUrl $ProxyUrl
if ($proxyWorks) {
    Write-Host "Proxy test passed. api.openai.com is reachable through the proxy."
} else {
    Write-Host "Proxy test did not pass."
    Write-Host "The environment variables can still be set, but you may need to switch proxy nodes or check the port."
}

Write-Section "Step 3: Set User Environment Variables"
$values = @{
    HTTP_PROXY = $ProxyUrl
    HTTPS_PROXY = $ProxyUrl
    ALL_PROXY = $ProxyUrl
    NO_PROXY = $NoProxy
}

foreach ($entry in $values.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "User")
    Set-Item -Path "Env:\$($entry.Key)" -Value $entry.Value
}

$values.GetEnumerator() |
    Sort-Object Name |
    ForEach-Object { Write-Host "$($_.Key)=$($_.Value)" }

Write-Section "Step 4: Restart Codex"
Write-Host "Done. Fully quit Codex Desktop, make sure no Codex.exe or codex.exe remains, then reopen Codex."
Write-Host "If Reconnecting still happens, run:"
Write-Host 'powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1'
