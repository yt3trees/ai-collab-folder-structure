<#
.SYNOPSIS
    Context Compression Layer setup script
.DESCRIPTION
    Adds Context Compression Layer to an existing ai-collab-folder-structure.
.PARAMETER ProjectName
    Target project name (if omitted, only workspace-level setup is run)
.PARAMETER Mini
    Specify for Mini Tier projects
.PARAMETER TemplateDir
    Directory containing template files
.EXAMPLE
    .\setup_context_layer.ps1
    .\setup_context_layer.ps1 -ProjectName "ERP-AI-Integration"
    .\setup_context_layer.ps1 -ProjectName "SupportTask" -Mini
#>

param(
    [string]$ProjectName,
    [switch]$Mini,
    [string]$TemplateDir
)

$configPath = Join-Path $env:USERPROFILE "Documents\Projects\_config\paths.json"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] paths.json not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$projectsRoot = Join-Path $env:USERPROFILE $config.localProjectsRoot

if (-not $TemplateDir) {
    $TemplateDir = Join-Path $PSScriptRoot "templates"
}

function Copy-IfNotExists {
    param([string]$Src, [string]$Dst)
    if ((Test-Path $Src) -and (-not (Test-Path $Dst))) {
        Copy-Item $Src $Dst
        Write-Host "  [CREATE] $Dst" -ForegroundColor Green
    }
    elseif (Test-Path $Dst) {
        Write-Host "  [SKIP]   $Dst (already exists)" -ForegroundColor Yellow
    }
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "  [CREATE] $Path" -ForegroundColor Green
    }
}

# --- Workspace-level setup ---
function Setup-Workspace {
    Write-Host "`n=== Workspace ===" -ForegroundColor Cyan
    $ctx = Join-Path $projectsRoot ".context"
    Ensure-Dir $ctx
    Copy-IfNotExists (Join-Path $TemplateDir "workspace_summary.md") (Join-Path $ctx "workspace_summary.md")
    Copy-IfNotExists (Join-Path $TemplateDir "current_focus.md") (Join-Path $ctx "current_focus.md")
    Copy-IfNotExists (Join-Path $TemplateDir "active_projects.md") (Join-Path $ctx "active_projects.md")
}

# --- Per-project setup ---
function Setup-Project {
    param([string]$Name, [switch]$IsMini)

    if ($IsMini) {
        $dir = Join-Path $projectsRoot "_mini\$Name"
    }
    else {
        $dir = Join-Path $projectsRoot $Name
    }

    if (-not (Test-Path $dir)) {
        Write-Host "[ERROR] Project not found: $dir" -ForegroundColor Red
        return
    }

    Write-Host "`n=== Project: $Name ===" -ForegroundColor Cyan
    $aiCtx = Join-Path $dir "_ai-context"
    $dlDir = Join-Path $aiCtx "decision_log"
    Ensure-Dir $aiCtx
    Ensure-Dir $dlDir

    Copy-IfNotExists (Join-Path $TemplateDir "project_summary.md") (Join-Path $aiCtx "project_summary.md")
    Copy-IfNotExists (Join-Path $TemplateDir "current_focus.md") (Join-Path $aiCtx "current_focus.md")
    Copy-IfNotExists (Join-Path $TemplateDir "decision_log_TEMPLATE.md") (Join-Path $dlDir "TEMPLATE.md")

    Write-Host "`n  [TODO] Add Context Compression Layer instructions to CLAUDE.md" -ForegroundColor Cyan
    Write-Host "         -> See templates/CLAUDE_MD_SNIPPET.md" -ForegroundColor White
}

# --- Execute ---
Write-Host "Context Compression Layer Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Setup-Workspace

if ($ProjectName) {
    Setup-Project -Name $ProjectName -IsMini:$Mini
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Write your current focus in current_focus.md" -ForegroundColor White
Write-Host "  2. Fill in project_summary.md (you can ask AI to draft it)" -ForegroundColor White
Write-Host "  3. Append the contents of CLAUDE_MD_SNIPPET.md to CLAUDE.md" -ForegroundColor White
