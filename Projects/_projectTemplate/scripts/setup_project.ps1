# Project Setup Script (Idempotent & Generic)
# Creates local folders, BOX shared folders, junctions, and CLAUDE.md symlink
# Usage: .\setup_project.ps1 -ProjectName "NewProject" [-Tier full|mini]

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("full", "mini")]
    [string]$Tier = "full",

    [Parameter(Mandatory = $false)]
    [ValidateSet("project", "domain")]
    [string]$Category = "project",

    [Parameter(Mandatory = $false)]
    [string[]]$ExternalSharedPaths = @()
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

# Determine project subpath based on Category and Tier
$categoryPrefix = if ($Category -eq "domain") { "_domains\" } else { "" }
if ($Tier -eq "mini") {
    $projectSubPath = "${categoryPrefix}_mini\$ProjectName"
}
else {
    $projectSubPath = "${categoryPrefix}$ProjectName"
}

$docRoot = Join-Path $localProjectsRoot $projectSubPath
$boxShared = Join-Path $boxProjectsRoot $projectSubPath
if ($ProjectName -eq "_INHOUSE") {
    $obsidianProject = Join-Path $obsidianVaultRoot "_INHOUSE"
}
else {
    $obsidianProject = Join-Path $obsidianVaultRoot "Projects\$projectSubPath"
}

Write-Host "=== $ProjectName Setup ===" -ForegroundColor Cyan
Write-Host "Tier: $Tier" -ForegroundColor DarkGray
Write-Host "Category: $Category" -ForegroundColor DarkGray
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

# Create BOX shared folders based on Tier
Write-Host ""
Write-Host "[BOX Shared Folders]" -ForegroundColor Yellow
if (-not (Test-Path $boxShared)) {
    New-Item -Path $boxShared -ItemType Directory -Force | Out-Null
    Write-Host "  Created: $ProjectName (root)" -ForegroundColor Green
}

if ($Tier -eq "mini") {
    # Mini tier: minimal folders
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
    # Full tier: structured folders
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

# Create Obsidian Vault project folders
Write-Host ""
Write-Host "[Obsidian Vault Folders]" -ForegroundColor Yellow
# Create same folders for all tiers
$obsidianFolders = @(
    "daily",
    "meetings",
    "specs",
    "notes",
    "troubleshooting",
    "ai-context",
    "ai-context\decision_log",
    "ai-context\focus_history"
)
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

# Create Project Index File
$indexFile = "$obsidianProject\00_$ProjectName-Index.md"
if (-not (Test-Path $indexFile)) {
    $indexContent = "# $ProjectName`n`n## Status`n- [ ] Active`n`n## Overview`n`n## Links`n- [[daily/]]`n- [[meetings/]]`n- [[specs/]]`n- [[notes/]]"
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

# 1.5 external_shared/ -> User Provided Box Paths (Optional)
$externalSharedDir = "$docRoot\external_shared"
$externalSharedConfig = "$boxShared\.external_shared_paths"

# Collect all paths to process (from args + existing config, merged)
$pathsToProcess = @()

# Read existing config if present
$existingPaths = @()
if (Test-Path $externalSharedConfig) {
    $existingPaths = @(Get-Content -Path $externalSharedConfig | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if ($ExternalSharedPaths -and $ExternalSharedPaths.Count -gt 0) {
    # Normalize new paths from arguments
    $newPaths = @()
    foreach ($p in $ExternalSharedPaths) {
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            $normalizedPath = $p -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
            $newPaths += $normalizedPath
        }
    }
    # Merge existing + new paths (deduplicate)
    $merged = @($existingPaths) + @($newPaths) | Select-Object -Unique
    $pathsToProcess = @($merged)
    # Save merged list to config file
    if ($pathsToProcess.Count -gt 0) {
        Set-Content -Path $externalSharedConfig -Value $pathsToProcess -Encoding UTF8
        Write-Host "  Saved External Shared Paths to: .external_shared_paths" -ForegroundColor Green
        if ($existingPaths.Count -gt 0) {
            Write-Host "    (Merged with $($existingPaths.Count) existing path(s))" -ForegroundColor DarkGray
        }
    }
}
elseif ($existingPaths.Count -gt 0) {
    $pathsToProcess = $existingPaths
}
elseif (Test-Path $externalSharedConfig) {
    # If no arguments provided, read from config
    $pathsToProcess = Get-Content -Path $externalSharedConfig
}

if ($pathsToProcess.Count -gt 0) {
    # Ensure external_shared directory exists
    if (-not (Test-Path $externalSharedDir)) {
        New-Item -Path $externalSharedDir -ItemType Directory -Force | Out-Null
        Write-Host "  Created: external_shared/ (Directory)" -ForegroundColor Green
    }
    elseif ((Get-Item $externalSharedDir).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Warning "  external_shared/ exists but is a junction from older version."
        Write-Host "    Please remove it and rerun." -ForegroundColor DarkYellow
    }

    foreach ($savedPath in $pathsToProcess) {
        if ([string]::IsNullOrWhiteSpace($savedPath)) { continue }
        
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($savedPath.Trim())
        $folderName = Split-Path $expandedPath -Leaf
        
        if ([string]::IsNullOrWhiteSpace($folderName)) {
            Write-Warning "  Could not determine folder name for: $expandedPath"
            continue
        }
        
        $externalSharedLink = "$externalSharedDir\$folderName"
        
        if (Test-Path $externalSharedLink) {
            $item = Get-Item $externalSharedLink -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $existingTarget = $item.Target
                if ($existingTarget -eq $expandedPath) {
                    Write-Host "  OK: external_shared/$folderName/ -> $expandedPath" -ForegroundColor Gray
                }
                else {
                    Write-Warning "  external_shared/$folderName/ points to $existingTarget instead of $expandedPath"
                }
            }
            else {
                Write-Warning "  external_shared/$folderName/ exists but is not a junction"
            }
        }
        elseif (Test-Path $expandedPath) {
            New-Item -ItemType Junction -Path $externalSharedLink -Target $expandedPath | Out-Null
            Write-Host "  Created: external_shared/$folderName/ -> $expandedPath" -ForegroundColor Green
        }
        else {
            Write-Warning "  External Shared Folder not found: $expandedPath"
            Write-Host "    Please check Box sync status or create manually" -ForegroundColor DarkYellow
        }
    }
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
$contextLink = "$docRoot\_ai-context\context"
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
    Write-Host "  AGENTS.md not found on BOX. Creating from template..." -ForegroundColor Cyan
    $templateAgentsPath = Join-Path (Split-Path $PSScriptRoot) "context-compression-layer\templates\AGENTS.md"
    if (Test-Path $templateAgentsPath) {
        $creationDate = (Get-Date).ToString("yyyy-MM-dd")
        $defaultContent = (Get-Content $templateAgentsPath -Raw -Encoding UTF8) `
            -replace '\{\{PROJECT_NAME\}\}', $ProjectName `
            -replace '\{\{CREATION_DATE\}\}', $creationDate
    }
    else {
        Write-Warning "  Template not found: $templateAgentsPath"
        $defaultContent = "# Project: $ProjectName`n`nTemplate not found: $templateAgentsPath"
    }
    Set-Content -Path $boxAgents -Value $defaultContent -Encoding UTF8
    Write-Host "  Created: $boxAgents" -ForegroundColor Green
}
else {
    Write-Host "  Found master: $boxAgents" -ForegroundColor Gray
}

# 3.2 Ensure CLAUDE.md exists on BOX (@AGENTS.md reference)
$boxClaude = "$boxShared\CLAUDE.md"
if (-not (Test-Path $boxClaude)) {
    Set-Content -Path $boxClaude -Value "@AGENTS.md" -Encoding UTF8
    Write-Host "  Created: $boxClaude (@AGENTS.md reference)" -ForegroundColor Green
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

# Create Local CLAUDE.md (@AGENTS.md reference)
Set-Content -Path $localClaude -Value "@AGENTS.md" -Encoding UTF8
Write-Host "  Created: CLAUDE.md -> Local Project Root (@AGENTS.md reference)" -ForegroundColor Green



# 5. Create .git/forCodex for Codex CLI AGENTS.md discovery
# Codex CLI stops traversal at .git/, so _work/ will find AGENTS.md in shared/
Write-Host ""
Write-Host "[Codex CLI Setup]" -ForegroundColor Yellow
$gitDir = "$boxShared\.git"
$forCodexFile = "$gitDir\forCodex"
if (-not (Test-Path $gitDir)) {
    New-Item -Path $gitDir -ItemType Directory -Force | Out-Null
    Write-Host "  Created: .git/" -ForegroundColor Green
}
else {
    Write-Host "  Exists: .git/" -ForegroundColor Gray
}
if (-not (Test-Path $forCodexFile)) {
    Set-Content -Path $forCodexFile -Value "This marker lets Codex CLI treat this directory as a repo root so that AGENTS.md is discoverable from _work/." -Encoding UTF8
    Write-Host "  Created: .git/forCodex" -ForegroundColor Green
}
else {
    Write-Host "  Exists: .git/forCodex" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Tier: $Tier" -ForegroundColor DarkGray
Write-Host "Category: $Category" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
$categoryArg = if ($Category -eq "domain") { " -Category domain" } else { "" }
if ($Tier -eq "mini") {
    Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName -Mini$categoryArg"
}
else {
    Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName$categoryArg"
}
Write-Host "  2. Create Obsidian notes for the project"
Write-Host "  3. Create AGENTS.md in: $boxShared\ (if not exists)"
