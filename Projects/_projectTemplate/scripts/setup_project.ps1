# Project Setup Script (Idempotent & Generic)
# Creates local folders, BOX shared folders, junctions, and CLAUDE.md symlink
# Usage: .\setup_project.ps1 -ProjectName "NewProject" [-Structure new|legacy] [-Tier full|mini]

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("new", "legacy")]
    [string]$Structure = "new",

    [Parameter(Mandatory = $false)]
    [ValidateSet("full", "mini")]
    [string]$Tier = "full"
)

# Load workspace paths config
$workspaceRoot = Split-Path (Split-Path $PSScriptRoot)
$pathsConfigFile = Join-Path $workspaceRoot "_config\paths.json"
if (-not (Test-Path $pathsConfigFile)) {
    Write-Error "Paths config not found: $pathsConfigFile"
    Write-Host "Please create _config\paths.json with localProjectsRoot, boxProjectsRoot, obsidianVaultRoot" -ForegroundColor DarkYellow
    exit 1
}
$pathsConfig = Get-Content $pathsConfigFile -Raw | ConvertFrom-Json

$localProjectsRoot = [System.Environment]::ExpandEnvironmentVariables($pathsConfig.localProjectsRoot)
$boxProjectsRoot = [System.Environment]::ExpandEnvironmentVariables($pathsConfig.boxProjectsRoot)
$obsidianVaultRoot = [System.Environment]::ExpandEnvironmentVariables($pathsConfig.obsidianVaultRoot)

# Determine project subpath based on Tier
if ($Tier -eq "mini") {
    $projectSubPath = "_mini\$ProjectName"
}
else {
    $projectSubPath = $ProjectName
}

$docRoot = Join-Path $localProjectsRoot $projectSubPath
$boxShared = Join-Path $boxProjectsRoot $projectSubPath
$obsidianProject = Join-Path $obsidianVaultRoot "Projects\$projectSubPath"

Write-Host "=== $ProjectName Setup ===" -ForegroundColor Cyan
Write-Host "Tier: $Tier" -ForegroundColor DarkGray
Write-Host "Structure: $Structure" -ForegroundColor DarkGray
Write-Host "Paths config: $pathsConfigFile" -ForegroundColor DarkGray
Write-Host ""

# Create local folders
Write-Host "[Local Folders]" -ForegroundColor Yellow
if ($Tier -eq "mini") {
    # Mini tier: minimal folders (no _ai-workspace, no scripts\config)
    $localFolders = @(
        '_ai-context',
        'development\source',
        'development\config',
        'development\scripts'
    )
}
else {
    # Full tier: all folders
    $localFolders = @(
        '_ai-context',
        '_ai-workspace',
        'development\source',
        'development\config',
        'development\scripts'
    )
}
foreach ($folder in $localFolders) {
    $path = "$docRoot\$folder"
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $folder" -ForegroundColor Green
    }
    else {
        Write-Host "  Exists: $folder" -ForegroundColor Gray
    }
}

# Create BOX shared folders based on Tier and Structure
Write-Host ""
Write-Host "[BOX Shared Folders]" -ForegroundColor Yellow
if (-not (Test-Path $boxShared)) {
    New-Item -Path $boxShared -ItemType Directory -Force | Out-Null
    Write-Host "  Created: $ProjectName (root)" -ForegroundColor Green
}

if ($Tier -eq "mini") {
    # Mini tier: minimal folders (Structure parameter ignored)
    $miniFolders = @(
        'docs',
        '_work'
    )
    foreach ($folder in $miniFolders) {
        $path = "$boxShared\$folder"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            Write-Host "  Created: $folder" -ForegroundColor Green
        }
        else {
            Write-Host "  Exists: $folder" -ForegroundColor Gray
        }
    }
}
else {
    # Full tier: structured folders based on Structure parameter
    if ($Structure -eq 'legacy') {
        $legacyFolders = @(
            '01_planning',
            '02_design',
            '03_development',
            '04_testing',
            '05_deployment',
            '06_operation',
            '07_communication',
            '08_issues',
            '09_training',
            '10_reference',
            '_work'
        )
        foreach ($folder in $legacyFolders) {
            $path = "$boxShared\$folder"
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  Created: $folder" -ForegroundColor Green
            }
            else {
                Write-Host "  Exists: $folder" -ForegroundColor Gray
            }
        }
    }
    else {
        # new structure (default)
        $newFolders = @(
            'docs\planning',
            'docs\design',
            'docs\testing',
            'docs\release',
            'reference\vendor',
            'reference\standards',
            'reference\external',
            'records\minutes',
            'records\reports',
            'records\reviews',
            '_work'
        )
        foreach ($folder in $newFolders) {
            $path = "$boxShared\$folder"
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  Created: $folder" -ForegroundColor Green
            }
            else {
                Write-Host "  Exists: $folder" -ForegroundColor Gray
            }
        }
    }
}

# Create Obsidian Vault project folders
Write-Host ""
Write-Host "[Obsidian Vault Folders]" -ForegroundColor Yellow
if ($Tier -eq "mini") {
    # Mini tier: notes + ai-context
    $obsidianFolders = @(
        "notes",
        "ai-context",
        "ai-context\decision_log",
        "ai-context\focus_history"
    )
}
else {
    # Full tier: all folders
    $obsidianFolders = @(
        "daily",
        "meetings",
        "specs",
        "notes",
        "weekly",
        "ai-context",
        "ai-context\decision_log",
        "ai-context\focus_history"
    )
}
foreach ($folder in $obsidianFolders) {
    $path = "$obsidianProject\$folder"
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "  Created: Projects/$ProjectName/$folder" -ForegroundColor Green
    }
    else {
        Write-Host "  Exists: Projects/$ProjectName/$folder" -ForegroundColor Gray
    }
}

# Copy templates to ai-context/ (only if not already present)
Write-Host ""
Write-Host "[AI Context Templates]" -ForegroundColor Yellow
$templateDir = Join-Path $PSScriptRoot "..\context-compression-layer\templates"
$obsAiCtx    = "$obsidianProject\ai-context"
$templateFiles = @(
    @{ Src = "project_summary.md";        Dst = "$obsAiCtx\project_summary.md" }
    @{ Src = "current_focus.md";          Dst = "$obsAiCtx\current_focus.md" }
    @{ Src = "file_map.md";               Dst = "$obsAiCtx\file_map.md" }
)
foreach ($t in $templateFiles) {
    $src = Join-Path $templateDir $t.Src
    $dst = $t.Dst
    if (Test-Path $dst) {
        Write-Host "  Exists: $([System.IO.Path]::GetFileName($dst))" -ForegroundColor Gray
    }
    elseif (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  Created: $([System.IO.Path]::GetFileName($dst))" -ForegroundColor Green
    }
    else {
        Write-Host "  Skip (template not found): $($t.Src)" -ForegroundColor DarkGray
    }
}

# Create Project Index File
$indexFile = "$obsidianProject\00_$ProjectName-Index.md"
if (-not (Test-Path $indexFile)) {
    $indexContent = "# $ProjectName`n`n## Status`n- [ ] Active`n`n## Overview`n`n## Links`n- [[daily/]]`n- [[meetings/]]`n- [[specs/]]`n- [[notes/]]"
    if ($Tier -eq "mini") {
        $indexContent = "# $ProjectName`n`n## Status`n- [ ] Active`n`n## Overview`n`n## Links`n- [[notes/]]"
    }
    Set-Content -Path $indexFile -Value $indexContent -Encoding UTF8
    Write-Host "  Created: 00_$ProjectName-Index.md" -ForegroundColor Green
}
else {
    Write-Host "  Exists: 00_$ProjectName-Index.md" -ForegroundColor Gray
}

# Create junctions
Write-Host ""
Write-Host "[Junctions]" -ForegroundColor Yellow

# 1. shared/ -> Box/Projects/{ProjectName}
$link = "$docRoot\shared"
if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = $item.Target
        if ($existingTarget -eq $boxShared) {
            Write-Host "  OK: shared/ -> $boxShared" -ForegroundColor Gray
        }
        else {
            Write-Warning "  shared/ points to different target: $existingTarget"
        }
    }
    else {
        Write-Warning "  shared/ exists but is not a junction (regular folder)"
        Write-Host "    Please backup and remove, then rerun this script" -ForegroundColor DarkYellow
    }
}
else {
    New-Item -ItemType Junction -Path $link -Target $boxShared | Out-Null
    Write-Host "  Created: shared/ -> $boxShared" -ForegroundColor Green
}

# 2. _ai-context/obsidian_notes/ -> Box/Obsidian-Vault/Projects/{ProjectName}
$obsLink = "$docRoot\_ai-context\obsidian_notes"
if (Test-Path $obsLink) {
    $item = Get-Item $obsLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = $item.Target
        if ($existingTarget -eq $obsidianProject) {
            Write-Host "  OK: obsidian_notes/ -> $obsidianProject" -ForegroundColor Gray
        }
        else {
            Write-Warning "  obsidian_notes/ points to different target: $existingTarget"
        }
    }
    else {
        Write-Warning "  obsidian_notes/ exists but is not a junction (regular folder)"
        Write-Host "    Please backup and remove, then rerun this script" -ForegroundColor DarkYellow
    }
}
elseif (Test-Path $obsidianProject) {
    New-Item -ItemType Junction -Path $obsLink -Target $obsidianProject | Out-Null
    Write-Host "  Created: obsidian_notes/ -> $obsidianProject" -ForegroundColor Green
}
else {
    Write-Warning "  Obsidian folder not found: $obsidianProject"
    Write-Host "    Please check Box sync status or create manually" -ForegroundColor DarkYellow
}

# 3. _ai-context/context/ -> Box/Obsidian-Vault/Projects/{ProjectName}/ai-context
$contextLink   = "$docRoot\_ai-context\context"
$obsidianAiCtx = "$obsidianProject\ai-context"
if (Test-Path $contextLink) {
    $item = Get-Item $contextLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = $item.Target
        if ($existingTarget -eq $obsidianAiCtx) {
            Write-Host "  OK: context/ -> $obsidianAiCtx" -ForegroundColor Gray
        }
        else {
            Write-Warning "  context/ points to different target: $existingTarget"
        }
    }
    else {
        Write-Warning "  context/ exists but is not a junction (regular folder)"
        Write-Host "    Please backup and remove, then rerun this script" -ForegroundColor DarkYellow
    }
}
elseif (Test-Path $obsidianAiCtx) {
    New-Item -ItemType Junction -Path $contextLink -Target $obsidianAiCtx | Out-Null
    Write-Host "  Created: context/ -> $obsidianAiCtx" -ForegroundColor Green
}
else {
    Write-Warning "  Obsidian ai-context folder not found: $obsidianAiCtx"
    Write-Host "    Please check Box sync status or create manually" -ForegroundColor DarkYellow
}



# 4. [AI Instruction Files] AGENTS.md (Master) & CLAUDE.md (Symlink)
Write-Host ""
Write-Host "[AI Instruction Files]" -ForegroundColor Yellow

# 3.1 Ensure Master AGENTS.md exists on BOX
$boxAgents = "$boxShared\AGENTS.md"
if (-not (Test-Path $boxAgents)) {
    Write-Host "  AGENTS.md not found on BOX. Creating default file..." -ForegroundColor Cyan
    $defaultContent = "# Project: $ProjectName`n`nSee _ProjectTemplate/AGENTS.md for full template."
    New-Item -Path $boxAgents -ItemType File -Value $defaultContent -Force | Out-Null
    Write-Host "  Created: $boxAgents" -ForegroundColor Green
}
else {
    Write-Host "  Found master: $boxAgents" -ForegroundColor Gray
}

# 3.2 Ensure CLAUDE.md exists on BOX (Copy of AGENTS.md)
$boxClaude = "$boxShared\CLAUDE.md"
if (-not (Test-Path $boxClaude)) {
    Copy-Item -Path $boxAgents -Destination $boxClaude -Force
    Write-Host "  Created: $boxClaude (Copy of AGENTS.md)" -ForegroundColor Green
}
else {
    Write-Host "  Exists: $boxClaude" -ForegroundColor Gray
}

# 3.3 Create Local Copies (No Symlinks)
$localAgents = "$docRoot\AGENTS.md"
$localClaude = "$docRoot\CLAUDE.md"

# Copy AGENTS.md -> Local AGENTS.md
Copy-Item -Path $boxAgents -Destination $localAgents -Force
Write-Host "  Copied: AGENTS.md -> Local Project Root" -ForegroundColor Green

# Copy AGENTS.md -> Local CLAUDE.md
Copy-Item -Path $boxAgents -Destination $localClaude -Force
Write-Host "  Copied: CLAUDE.md -> Local Project Root (Duplicate for Claude CLI)" -ForegroundColor Green



Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Tier: $Tier" -ForegroundColor DarkGray
Write-Host "Structure: $Structure" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
if ($Tier -eq "mini") {
    Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName -Mini"
}
else {
    Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName"
}
Write-Host "  2. Create Obsidian notes for the project"
Write-Host "  3. Create AGENTS.md in: $boxShared\ (if not exists)"
