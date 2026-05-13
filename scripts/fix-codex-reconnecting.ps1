[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [int[]]$CommonProxyPorts = @(7897, 7890, 10809, 1080),
    [string]$NoProxy = "localhost,127.0.0.1,::1"
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
    }

    if ($Value -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        return "http://$Value"
    }

    return $Value
}

function Test-ProxyUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    try {
        curl.exe -sS -I --max-time 20 -x $Url "https://api.openai.com/v1/models" | Out-Null
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
    foreach ($port in $CommonProxyPorts) {
        $result = Test-NetConnection 127.0.0.1 -Port $port -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            $ProxyUrl = "http://127.0.0.1:$port"
            Write-Host "Found listening local proxy port: $port"
            break
        }
    }
}

$ProxyUrl = Normalize-ProxyUrl $ProxyUrl

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    Write-Host "No proxy was found."
    Write-Host "Open your proxy app, enable system proxy, then rerun this script."
    Write-Host "Or specify it manually, for example:"
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"'
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
