[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter()]
    [ValidateSet("full", "preview", "section")]
    [string]$Mode = "full",

    [Parameter()]
    [int]$PreviewLines = 40,

    [Parameter()]
    [string]$Heading = ""
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

$filePath = Join-Path $vaultPath $Path
if (-not (Test-Path $filePath)) {
    Write-Error "Note file not found: $filePath"
    exit 1
}

try {
    $text = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
} catch {
    Write-Error "Failed to read note file: $filePath - $($_.Exception.Message)"
    exit 1
}

$lines = $text -split "`n"

function Write-NoteHeader {
    param(
        [string]$Path,
        [string]$Mode,
        [string]$Heading
    )
    Write-Output "---OBSIDIAN-NOTE-BEGIN---"
    Write-Output "PATH: $Path"
    Write-Output "MODE: $Mode"
    if ($Heading) {
        Write-Output "HEADING: $Heading"
    }
    Write-Output "---CONTENT-START---"
}

function Write-NoteFooter {
    Write-Output "---CONTENT-END---"
    Write-Output "---OBSIDIAN-NOTE-END---"
}

if ($Mode -eq "full") {
    Write-NoteHeader -Path $Path -Mode $Mode -Heading $Heading
    $lines | ForEach-Object { Write-Output $_ }
    Write-NoteFooter
}
elseif ($Mode -eq "preview") {
    Write-NoteHeader -Path $Path -Mode $Mode -Heading $Heading
    $max = [Math]::Min($PreviewLines, $lines.Count)
    for ($i = 0; $i -lt $max; $i++) {
        Write-Output $lines[$i]
    }
    Write-NoteFooter
}
elseif ($Mode -eq "section") {
    if (-not $Heading) {
        Write-Error "-Heading is required when Mode=section."
        exit 1
    }

    # Find heading line
    $targetIndex = -1
    $targetLevel = 0

    # If input contains # prefix like "## XXX", use as-is
    if ($Heading -match "^#{1,6} ") {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].TrimEnd() -eq $Heading.TrimEnd()) {
                $targetIndex = $i
                $targetLevel = ($Heading -replace "^(#+).*$", '$1').Length
                break
            }
        }
    }
    else {
        # Plain text: match as heading
        $escaped = [regex]::Escape($Heading.Trim())
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^(#{1,6})\s+$escaped\s*$") {
                $targetIndex = $i
                $targetLevel = $matches[1].Length
                break
            }
        }
    }

    Write-NoteHeader -Path $Path -Mode $Mode -Heading $Heading

    if ($targetIndex -lt 0) {
        Write-Output "[Section not found] Heading: $Heading"
        Write-NoteFooter
        exit 0
    }

    # Find section end (next heading at same or higher level)
    $endIndex = $lines.Count
    for ($i = $targetIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^(#{1,6})\s+.+") {
            $level = $matches[1].Length
            if ($level -le $targetLevel) {
                $endIndex = $i
                break
            }
        }
    }

    for ($i = $targetIndex; $i -lt $endIndex; $i++) {
        Write-Output $lines[$i]
    }
    Write-NoteFooter
}
else {
    Write-Error "Invalid Mode: $Mode"
    exit 1
}
