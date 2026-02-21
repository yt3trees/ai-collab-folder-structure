# Project Health Check Script (Generic)
# Checks junctions, CLAUDE.md symlink, and .lnk shortcuts for any project
# Usage: .\check_project.ps1 -ProjectName "ProjectName" [-Mini]

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$false)]
    [switch]$Mini
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

# Determine project subpath based on Support flag
if ($Mini) {
    $projectSubPath = "_mini\$ProjectName"
} else {
    $projectSubPath = $ProjectName
}

$docRoot = Join-Path $localProjectsRoot $projectSubPath
$boxShared = Join-Path $boxProjectsRoot $projectSubPath
$obsidianProject = Join-Path $obsidianVaultRoot "Projects\$projectSubPath"

Write-Host "=== $ProjectName Health Check ===" -ForegroundColor Cyan
if ($Mini) {
    Write-Host "Tier: mini" -ForegroundColor DarkGray
}
Write-Host "Paths config: $pathsConfigFile" -ForegroundColor DarkGray

# Check if project exists
if (-not (Test-Path $docRoot)) {
    Write-Error "Project not found: $docRoot"
    exit 1
}

# Detect structure
$hasLegacy = Test-Path "$boxShared\01_planning"
$hasNew = Test-Path "$boxShared\docs"
if ($hasLegacy) { $structure = 'legacy' }
elseif ($hasNew) { $structure = 'new' }
else { $structure = 'none' }
Write-Host "Structure: $structure" -ForegroundColor DarkGray
Write-Host ""

# Check Junctions
Write-Host "[Junctions]" -ForegroundColor Yellow

# shared/
$link = "$docRoot\shared"
if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -eq $boxShared) {
            Write-Host "  OK: shared/ -> $boxShared" -ForegroundColor Green
        } else {
            Write-Host "  [!] shared/ points to: $target" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] shared/ is a regular folder (not junction)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] shared/ missing - run setup_project.ps1" -ForegroundColor Yellow
}

# obsidian_notes/
$obsLink = "$docRoot\_ai-context\obsidian_notes"
if (Test-Path $obsLink) {
    $item = Get-Item $obsLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -eq $obsidianProject) {
            Write-Host "  OK: obsidian_notes/ -> $obsidianProject" -ForegroundColor Green
        } else {
            Write-Host "  [!] obsidian_notes/ points to: $target" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] obsidian_notes/ is a regular folder (not junction)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] obsidian_notes/ missing - run setup_project.ps1" -ForegroundColor Yellow
}

# context/
$contextLink   = "$docRoot\_ai-context\context"
$obsidianAiCtx = "$obsidianProject\ai-context"
if (Test-Path $contextLink) {
    $item = Get-Item $contextLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -eq $obsidianAiCtx) {
            Write-Host "  OK: context/ -> $obsidianAiCtx" -ForegroundColor Green
        } else {
            Write-Host "  [!] context/ points to: $target" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] context/ is a regular folder (not junction)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] context/ missing - run setup_project.ps1" -ForegroundColor Yellow
}

# [AI Instruction Files]
Write-Host ""
Write-Host "[AI Instruction Files]" -ForegroundColor Yellow

# AGENTS.md (Local Copy)
$localAgents = "$docRoot\AGENTS.md"
$boxAgents = "$boxShared\AGENTS.md"

if (Test-Path $localAgents) {
    Write-Host "  OK: AGENTS.md (Local Copy)" -ForegroundColor Green
    if (-not (Test-Path $boxAgents)) {
        Write-Host "  [!] Master AGENTS.md missing on BOX" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] AGENTS.md missing locally - run setup_project.ps1" -ForegroundColor Yellow
}

# CLAUDE.md (Local Copy)
$localClaude = "$docRoot\CLAUDE.md"

if (Test-Path $localClaude) {
    Write-Host "  OK: CLAUDE.md (Local Copy)" -ForegroundColor Green
} else {
    Write-Host "  [!] CLAUDE.md missing locally - run setup_project.ps1" -ForegroundColor Yellow
}

# Folder Structure
Write-Host ""
Write-Host "[Folder Structure]" -ForegroundColor Yellow
if (Test-Path $boxShared) {
    $subdirs = Get-ChildItem -Path $boxShared -Directory -ErrorAction SilentlyContinue | Select-Object -First 5
    if ($subdirs) {
        Write-Host "  BOX Shared:" -ForegroundColor Gray
        foreach ($dir in $subdirs) {
            Write-Host "    - $($dir.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [!] BOX shared folder is empty" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] BOX shared folder not found" -ForegroundColor Yellow
}

# .lnk check
Write-Host ""
Write-Host "[Shortcuts (.lnk)]" -ForegroundColor Yellow
if (Test-Path $boxShared) {
    $shell = New-Object -ComObject WScript.Shell
    $lnkFiles = Get-ChildItem -Path $boxShared -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue
    if ($lnkFiles) {
        $broken = 0
        foreach ($lnk in $lnkFiles) {
            $shortcut = $shell.CreateShortcut($lnk.FullName)
            $target = $shortcut.TargetPath
            if (-not (Test-Path $target)) {
                Write-Host "  [!] Broken: $($lnk.Name) -> $target" -ForegroundColor Yellow
                $broken++
            }
        }
        if ($broken -eq 0) {
            Write-Host "  All shortcuts valid" -ForegroundColor Green
        } else {
            Write-Host "  Broken: $broken" -ForegroundColor Red
        }
    } else {
        Write-Host "  (No .lnk files)" -ForegroundColor Gray
    }
} else {
    Write-Host "  (Skipped)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[CCL Files]" -ForegroundColor Yellow
$aiCtxContent = Join-Path $docRoot "_ai-context\context"
$today = Get-Date

$summaryFile = Join-Path $aiCtxContent "project_summary.md"
if (Test-Path $summaryFile) {
    $lastWrite = (Get-Item $summaryFile).LastWriteTime
    $daysSince = ($today - $lastWrite).Days
    if ($daysSince -ge 14) {
        Write-Host "  WARN: context/project_summary.md ($daysSince days old - consider updating)" -ForegroundColor Yellow
    } else {
        Write-Host "  OK: context/project_summary.md (${daysSince}d ago)" -ForegroundColor Green
    }
} else {
    Write-Host "  INFO: context/project_summary.md not found (run setup_context_layer.ps1?)" -ForegroundColor Gray
}

$focusFile = Join-Path $aiCtxContent "current_focus.md"
if (Test-Path $focusFile) {
    $lastWrite = (Get-Item $focusFile).LastWriteTime
    $daysSince = ($today - $lastWrite).Days
    if ($daysSince -ge 7) {
        Write-Host "  WARN: context/current_focus.md ($daysSince days old - consider updating)" -ForegroundColor Yellow
    } else {
        Write-Host "  OK: context/current_focus.md (${daysSince}d ago)" -ForegroundColor Green
    }
} else {
    Write-Host "  INFO: context/current_focus.md not found (run setup_context_layer.ps1?)" -ForegroundColor Gray
}

$decisionLogDir = Join-Path $aiCtxContent "decision_log"
if (Test-Path $decisionLogDir) {
    $dlCount = (Get-ChildItem $decisionLogDir -Filter "*.md" -Exclude "TEMPLATE.md" -ErrorAction SilentlyContinue).Count
    Write-Host "  OK: context/decision_log/ ($dlCount entries)" -ForegroundColor Green
} else {
    Write-Host "  INFO: context/decision_log/ not found (run setup_context_layer.ps1?)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Check completed" -ForegroundColor Cyan
