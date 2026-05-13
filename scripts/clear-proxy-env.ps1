[CmdletBinding()]
param()

$keys = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")

foreach ($key in $keys) {
    [Environment]::SetEnvironmentVariable($key, $null, "User")
    Remove-Item -Path "Env:\$key" -ErrorAction SilentlyContinue
}

Write-Host "Removed user-level proxy environment variables:"
$keys | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "Fully quit Codex Desktop and reopen it for these settings to take effect."
