[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-zA-Z][a-zA-Z0-9+.-]*://")]
    [string]$ProxyUrl,

    [string]$NoProxy = "localhost,127.0.0.1,::1"
)

$keys = @{
    HTTP_PROXY = $ProxyUrl
    HTTPS_PROXY = $ProxyUrl
    ALL_PROXY = $ProxyUrl
    NO_PROXY = $NoProxy
}

foreach ($entry in $keys.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "User")
    Set-Item -Path "Env:\$($entry.Key)" -Value $entry.Value
}

Write-Host "User-level proxy environment variables were set:"
$keys.GetEnumerator() |
    Sort-Object Name |
    ForEach-Object { Write-Host "$($_.Key)=$($_.Value)" }

Write-Host ""
Write-Host "Fully quit Codex Desktop and reopen it for these settings to take effect."
