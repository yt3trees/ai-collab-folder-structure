[CmdletBinding()]
param(
    [Parameter()]
    [int]$Days = 7,

    [Parameter()]
    [int]$MaxResults = 20
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load vault path from config.json (fallback to env var)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseDir = Split-Path -Parent $scriptDir
$configPath = Join-Path $baseDir "config.json"
$vaultPath = $null
if (Test-Path $configPath) {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $vaultPath = $config.vaultPath
    if ($vaultPath) {
        $vaultPath = [System.Environment]::ExpandEnvironmentVariables($vaultPath)
    }
}
if (-not $vaultPath -or -not (Test-Path $vaultPath)) {
    $vaultPath = $env:OBSIDIAN_VAULT_PATH
}
if (-not $vaultPath) {
    Write-Error "Vault path is not configured. Please set it in config.json or the OBSIDIAN_VAULT_PATH environment variable."
    exit 1
}
if (-not (Test-Path $vaultPath)) {
    Write-Error "Vault path not found: $vaultPath"
    exit 1
}

$since = (Get-Date).AddDays(-$Days)

$results = Get-ChildItem -Path $vaultPath -Filter "*.md" -Recurse |
    Where-Object { $_.LastWriteTime -gt $since } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $MaxResults

if ($results) {
    foreach ($r in $results) {
        $relativePath = $r.FullName.Replace($vaultPath, "").TrimStart("\", "/")
        $updated = $r.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Output "UPDATED:$updated|PATH:$relativePath"
    }
} else {
    Write-Output "No notes updated in the last $Days days."
}

