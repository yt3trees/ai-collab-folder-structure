[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Content,

    [Parameter()]
    [string]$Folder = ""
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

$today = Get-Date -Format "yyyy-MM-dd"
$safeTitle = $Title -replace '[\\/:*?"<>|]', '_'
$filename = "$today-$safeTitle.md"

$targetDir = $vaultPath
if ($Folder) {
    $targetDir = Join-Path $vaultPath $Folder
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }
}

$filePath = Join-Path $targetDir $filename

if (Test-Path $filePath) {
    Write-Error "File already exists: $filePath"
    exit 1
}

$noteContent = @"
# $Title

Created: $today

$Content
"@

Set-Content -Path $filePath -Value $noteContent -Encoding UTF8
Write-Output "Note saved: $filePath"
