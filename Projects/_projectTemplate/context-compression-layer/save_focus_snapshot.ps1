<#
.SYNOPSIS
    Save a daily snapshot of current_focus.md to focus_history/
.DESCRIPTION
    Copies the current_focus.md to focus_history/YYYY-MM-DD.md.
    If today's snapshot already exists, it is overwritten (1 file per day).
    Skips if current_focus.md is empty or still the default template.
.PARAMETER ProjectName
    Target project name
.PARAMETER Mini
    Specify for Mini Tier projects
.PARAMETER Workspace
    Snapshot the workspace-level current_focus.md (.context/) instead of a project
.EXAMPLE
    .\save_focus_snapshot.ps1 -ProjectName "ProjectA"
    .\save_focus_snapshot.ps1 -ProjectName "SupportTask" -Mini
    .\save_focus_snapshot.ps1 -Workspace
#>

param(
    [string]$ProjectName,
    [switch]$Mini,
    [ValidateSet("project", "domain")]
    [string]$Category = "project",
    [switch]$Workspace
)

$configPath = Join-Path $env:USERPROFILE "Documents\Projects\_config\paths.json"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] paths.json not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$projectsRoot = [System.Environment]::ExpandEnvironmentVariables($config.localProjectsRoot)

if ($Workspace) {
    $ctxDir = Join-Path $projectsRoot ".context"
}
elseif ($ProjectName) {
    $categoryPrefix = if ($Category -eq "domain") { "_domains\" } else { "" }
    if ($Mini) {
        $projDir = Join-Path $projectsRoot "${categoryPrefix}_mini\$ProjectName"
    }
    else {
        $projDir = Join-Path $projectsRoot "${categoryPrefix}$ProjectName"
    }
    # Files live in _ai-context/context/ (junction to Obsidian ai-context/)
    $ctxDir = Join-Path $projDir "_ai-context\context"
}
else {
    Write-Host "[ERROR] Specify -ProjectName or -Workspace" -ForegroundColor Red
    exit 1
}

$focusFile = Join-Path $ctxDir "current_focus.md"
$historyDir = Join-Path $ctxDir "focus_history"

# Validate source
if (-not (Test-Path $focusFile)) {
    Write-Host "[SKIP] current_focus.md not found: $focusFile" -ForegroundColor Yellow
    exit 0
}

# Check if file is still the default template (all section bodies are empty "- ")
$content = Get-Content $focusFile -Raw -Encoding UTF8

# Strip multi-line HTML comments before checking
$stripped = $content -replace '(?s)<!--.*?-->', ''
$lines = ($stripped -split "`n") | ForEach-Object { $_.Trim() }
$contentLines = $lines | Where-Object {
    $_ -ne "" -and
    $_ -ne "-" -and
    -not $_.StartsWith("#") -and
    -not $_.StartsWith("---") -and
    -not ($_ -match '^\u66f4\u65b0:')
}

if ($contentLines.Count -eq 0) {
    Write-Host "[SKIP] current_focus.md is empty (default template)" -ForegroundColor Yellow
    exit 0
}

# Ensure history directory exists
if (-not (Test-Path $historyDir)) {
    New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
    Write-Host "[CREATE] $historyDir" -ForegroundColor Green
}

# Save snapshot
$today = Get-Date -Format "yyyy-MM-dd"
$snapshotFile = Join-Path $historyDir "$today.md"

Copy-Item -Path $focusFile -Destination $snapshotFile -Force
Write-Host "[SAVE] $snapshotFile" -ForegroundColor Green

# Update the 更新: line in current_focus.md
$updatedContent = $content -replace "更新:.*$", "更新: $today"
Set-Content -Path $focusFile -Value $updatedContent -Encoding UTF8 -NoNewline
