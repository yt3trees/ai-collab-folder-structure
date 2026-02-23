# Project Tier Conversion Script
# Converts a project between mini and full tiers
# Usage: .\convert_tier.ps1 -ProjectName "ProjectName" -To full|mini [-DryRun]

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("full", "mini")]
    [string]$To,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
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

# Determine source and destination paths
if ($To -eq "full") {
    # Mini -> Full
    $srcSubPath = "_mini\$ProjectName"
    $dstSubPath = $ProjectName
    $fromTier = "mini"
    $toTier = "full"
}
else {
    # Full -> Mini
    $srcSubPath = $ProjectName
    $dstSubPath = "_mini\$ProjectName"
    $fromTier = "full"
    $toTier = "mini"
}

$srcLocal = Join-Path $localProjectsRoot $srcSubPath
$dstLocal = Join-Path $localProjectsRoot $dstSubPath
$srcBox = Join-Path $boxProjectsRoot $srcSubPath
$dstBox = Join-Path $boxProjectsRoot $dstSubPath
$srcObsidian = Join-Path $obsidianVaultRoot "Projects\$srcSubPath"
$dstObsidian = Join-Path $obsidianVaultRoot "Projects\$dstSubPath"

# === Header ===
Write-Host ""
if ($DryRun) {
    Write-Host "=== $ProjectName Tier Conversion (DRY RUN) ===" -ForegroundColor Magenta
}
else {
    Write-Host "=== $ProjectName Tier Conversion ===" -ForegroundColor Cyan
}
Write-Host "From: $fromTier -> To: $toTier" -ForegroundColor DarkGray
Write-Host "Paths config: $pathsConfigFile" -ForegroundColor DarkGray
Write-Host ""

# === Validation ===
Write-Host "[Validation]" -ForegroundColor Yellow

# Check source exists
if (-not (Test-Path $srcLocal)) {
    Write-Error "Source project not found: $srcLocal"
    exit 1
}
Write-Host "  Source (Local): $srcLocal" -ForegroundColor Gray

# Check source is not already the target tier
if ($To -eq "full" -and -not $srcLocal.Contains("_mini")) {
    Write-Error "Project '$ProjectName' is already a full tier project."
    exit 1
}
if ($To -eq "mini" -and $srcLocal.Contains("_mini")) {
    Write-Error "Project '$ProjectName' is already a mini tier project."
    exit 1
}

# Check destination does not exist
$conflicts = @()
if (Test-Path $dstLocal) { $conflicts += "Local: $dstLocal" }
if (Test-Path $dstBox) { $conflicts += "BOX: $dstBox" }
if (Test-Path $dstObsidian) { $conflicts += "Obsidian: $dstObsidian" }

if ($conflicts.Count -gt 0) {
    Write-Host "  Destination already exists:" -ForegroundColor Red
    foreach ($c in $conflicts) {
        Write-Host "    - $c" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Please remove or rename the existing destination before conversion." -ForegroundColor DarkYellow
    exit 1
}
Write-Host "  Destination (Local): $dstLocal" -ForegroundColor Gray
Write-Host ""

# === Warnings for Full -> Mini ===
if ($To -eq "mini") {
    Write-Host "[Warnings - Full-only items]" -ForegroundColor Yellow
    $hasWarnings = $false

    # Check _ai-workspace
    $aiWorkspace = Join-Path $srcLocal "_ai-workspace"
    if (Test-Path $aiWorkspace) {
        $files = Get-ChildItem -Path $aiWorkspace -Recurse -File -ErrorAction SilentlyContinue
        if ($files.Count -gt 0) {
            Write-Host "  WARNING: _ai-workspace/ contains $($files.Count) file(s) - will be preserved in move" -ForegroundColor Yellow
            $hasWarnings = $true
        }
    }

    # Check reference/ and records/ on BOX
    if (Test-Path $srcBox) {
        foreach ($folder in @("reference", "records")) {
            $folderPath = Join-Path $srcBox $folder
            if (Test-Path $folderPath) {
                $files = Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    Write-Host "  WARNING: BOX $folder/ contains $($files.Count) file(s) - will be preserved in move" -ForegroundColor Yellow
                    $hasWarnings = $true
                }
            }
        }

        # Check docs/ subfolders
        $docsPath = Join-Path $srcBox "docs"
        if (Test-Path $docsPath) {
            $subDirs = Get-ChildItem -Path $docsPath -Directory -ErrorAction SilentlyContinue
            if ($subDirs.Count -gt 0) {
                $totalFiles = 0
                foreach ($sub in $subDirs) {
                    $totalFiles += (Get-ChildItem -Path $sub.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
                }
                if ($totalFiles -gt 0) {
                    Write-Host "  WARNING: BOX docs/ subfolders contain $totalFiles file(s) - will be preserved in move" -ForegroundColor Yellow
                    $hasWarnings = $true
                }
            }
        }
    }

    # Check Obsidian folders
    if (Test-Path $srcObsidian) {
        foreach ($folder in @("daily", "meetings", "specs")) {
            $folderPath = Join-Path $srcObsidian $folder
            if (Test-Path $folderPath) {
                $files = Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    Write-Host "  WARNING: Obsidian $folder/ contains $($files.Count) file(s) - will be preserved in move" -ForegroundColor Yellow
                    $hasWarnings = $true
                }
            }
        }
    }

    if (-not $hasWarnings) {
        Write-Host "  No warnings - all full-only folders are empty or absent" -ForegroundColor Green
    }
    Write-Host ""
}

# === Confirmation (non-DryRun, non-Force) ===
if (-not $DryRun -and -not $Force) {
    Write-Host "This will convert '$ProjectName' from $fromTier to $toTier tier." -ForegroundColor Cyan
    Write-Host "  Layer 1: $srcLocal -> $dstLocal" -ForegroundColor Gray
    if (Test-Path $srcBox) {
        Write-Host "  Layer 3: $srcBox -> $dstBox" -ForegroundColor Gray
    }
    if (Test-Path $srcObsidian) {
        Write-Host "  Layer 2: $srcObsidian -> $dstObsidian" -ForegroundColor Gray
    }
    Write-Host ""
    $response = Read-Host "Continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor DarkYellow
        exit 0
    }
    Write-Host ""
}

# === Helper function: Remove junction/symlink safely ===
function Remove-LinkSafely {
    param([string]$Path, [string]$Label)

    if (-not (Test-Path $Path)) {
        Write-Host "  Skip: $Label (not found)" -ForegroundColor Gray
        return
    }

    $item = Get-Item $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if ($DryRun) {
            Write-Host "  [DRY] Would remove: $Label" -ForegroundColor Magenta
        }
        else {
            # Use cmd /c rmdir for junctions to avoid deleting target content
            cmd /c rmdir "$Path" 2>$null
            if (Test-Path $Path) {
                Remove-Item $Path -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  Removed: $Label" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  $Label is not a junction/symlink (regular item)" -ForegroundColor Gray
    }
}

# === Step 1: Remove junctions ===
Write-Host "[Step 1] Remove Junctions & Links" -ForegroundColor Yellow

$sharedLink = Join-Path $srcLocal "shared"
Remove-LinkSafely -Path $sharedLink -Label "shared/ junction"

$obsLink = Join-Path $srcLocal "_ai-context\obsidian_notes"
Remove-LinkSafely -Path $obsLink -Label "obsidian_notes/ junction"

$contextLink = Join-Path $srcLocal "_ai-context\context"
Remove-LinkSafely -Path $contextLink -Label "context/ junction"

# Remove skill junctions (.claude, .codex, .gemini)
foreach ($cli in @(".claude", ".codex", ".gemini")) {
    $cliPath = Join-Path $srcLocal $cli
    Remove-LinkSafely -Path $cliPath -Label "$cli junction"
}

# Remove AI instruction file copies
foreach ($file in @("AGENTS.md", "CLAUDE.md")) {
    $filePath = Join-Path $srcLocal $file
    if (Test-Path $filePath) {
        $item = Get-Item $filePath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # It's a symlink
            if ($DryRun) {
                Write-Host "  [DRY] Would remove symlink: $file" -ForegroundColor Magenta
            }
            else {
                Remove-Item $filePath -Force
                Write-Host "  Removed symlink: $file" -ForegroundColor Green
            }
        }
        else {
            # It's a file copy - just remove it (will be recreated)
            if ($DryRun) {
                Write-Host "  [DRY] Would remove copy: $file" -ForegroundColor Magenta
            }
            else {
                Remove-Item $filePath -Force
                Write-Host "  Removed copy: $file" -ForegroundColor Green
            }
        }
    }
}
Write-Host ""

# === Step 2: Move Layer 3 (BOX) ===
Write-Host "[Step 2] Move Layer 3 (BOX Shared)" -ForegroundColor Yellow
if (Test-Path $srcBox) {
    if ($DryRun) {
        Write-Host "  [DRY] Would move: $srcBox -> $dstBox" -ForegroundColor Magenta
    }
    else {
        $dstParent = Split-Path $dstBox
        if (-not (Test-Path $dstParent)) {
            New-Item -Path $dstParent -ItemType Directory -Force | Out-Null
        }
        Move-Item -Path $srcBox -Destination $dstBox -Force
        Write-Host "  Moved: $srcBox -> $dstBox" -ForegroundColor Green
    }
}
else {
    Write-Host "  Skip: BOX folder not found" -ForegroundColor Gray
}
Write-Host ""

# === Step 3: Move Layer 2 (Obsidian) ===
Write-Host "[Step 3] Move Layer 2 (Obsidian)" -ForegroundColor Yellow
if (Test-Path $srcObsidian) {
    if ($DryRun) {
        Write-Host "  [DRY] Would move: $srcObsidian -> $dstObsidian" -ForegroundColor Magenta
    }
    else {
        $dstParent = Split-Path $dstObsidian
        if (-not (Test-Path $dstParent)) {
            New-Item -Path $dstParent -ItemType Directory -Force | Out-Null
        }
        Move-Item -Path $srcObsidian -Destination $dstObsidian -Force
        Write-Host "  Moved: $srcObsidian -> $dstObsidian" -ForegroundColor Green
    }
}
else {
    Write-Host "  Skip: Obsidian folder not found" -ForegroundColor Gray
}
Write-Host ""

# === Step 4: Move Layer 1 (Local) ===
Write-Host "[Step 4] Move Layer 1 (Local)" -ForegroundColor Yellow
if ($DryRun) {
    Write-Host "  [DRY] Would move: $srcLocal -> $dstLocal" -ForegroundColor Magenta
}
else {
    $dstParent = Split-Path $dstLocal
    if (-not (Test-Path $dstParent)) {
        New-Item -Path $dstParent -ItemType Directory -Force | Out-Null
    }
    Move-Item -Path $srcLocal -Destination $dstLocal -Force
    Write-Host "  Moved: $srcLocal -> $dstLocal" -ForegroundColor Green
}
Write-Host ""

# === Step 5: Create additional folders ===
Write-Host "[Step 5] Create Additional Folders" -ForegroundColor Yellow

if ($To -eq "full") {
    # Mini -> Full: add full-only folders
    # Local: _ai-workspace
    $aiWorkspace = Join-Path $dstLocal "_ai-workspace"
    if ($DryRun) {
        Write-Host "  [DRY] Would create: _ai-workspace/" -ForegroundColor Magenta
    }
    else {
        if (-not (Test-Path $aiWorkspace)) {
            New-Item -Path $aiWorkspace -ItemType Directory -Force | Out-Null
            Write-Host "  Created: _ai-workspace/" -ForegroundColor Green
        }
        else {
            Write-Host "  Exists: _ai-workspace/" -ForegroundColor Gray
        }
    }

    # Local: development/scripts (mini may not have it)
    $devScripts = Join-Path $dstLocal "development\scripts"
    if ($DryRun) {
        Write-Host "  [DRY] Would create: development/scripts/" -ForegroundColor Magenta
    }
    else {
        if (-not (Test-Path $devScripts)) {
            New-Item -Path $devScripts -ItemType Directory -Force | Out-Null
            Write-Host "  Created: development/scripts/" -ForegroundColor Green
        }
        else {
            Write-Host "  Exists: development/scripts/" -ForegroundColor Gray
        }
    }

    # BOX: structured folders
    $boxFolders = @(
        'docs\planning', 'docs\design', 'docs\testing', 'docs\release',
        'reference\vendor', 'reference\standards', 'reference\external',
        'records\minutes', 'records\reports', 'records\reviews', '_work'
    )
    foreach ($folder in $boxFolders) {
        $path = Join-Path $dstBox $folder
        if ($DryRun) {
            if (-not (Test-Path $path)) {
                Write-Host "  [DRY] Would create BOX: $folder" -ForegroundColor Magenta
            }
        }
        else {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  Created BOX: $folder" -ForegroundColor Green
            }
            else {
                Write-Host "  Exists BOX: $folder" -ForegroundColor Gray
            }
        }
    }

    # Obsidian: full folders
    $obsidianFolders = @("daily", "meetings", "specs", "notes")
    foreach ($folder in $obsidianFolders) {
        $path = Join-Path $dstObsidian $folder
        if ($DryRun) {
            if (-not (Test-Path $path)) {
                Write-Host "  [DRY] Would create Obsidian: $folder" -ForegroundColor Magenta
            }
        }
        else {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  Created Obsidian: $folder" -ForegroundColor Green
            }
            else {
                Write-Host "  Exists Obsidian: $folder" -ForegroundColor Gray
            }
        }
    }
}
else {
    # Full -> Mini: ensure minimum folders exist
    # BOX: docs and _work
    foreach ($folder in @("docs", "_work")) {
        $path = Join-Path $dstBox $folder
        if ($DryRun) {
            if (-not (Test-Path $path)) {
                Write-Host "  [DRY] Would create BOX: $folder" -ForegroundColor Magenta
            }
        }
        else {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  Created BOX: $folder" -ForegroundColor Green
            }
            else {
                Write-Host "  Exists BOX: $folder" -ForegroundColor Gray
            }
        }
    }

    # Obsidian: notes
    $notesPath = Join-Path $dstObsidian "notes"
    if ($DryRun) {
        if (-not (Test-Path $notesPath)) {
            Write-Host "  [DRY] Would create Obsidian: notes" -ForegroundColor Magenta
        }
    }
    else {
        if (-not (Test-Path $notesPath)) {
            New-Item -Path $notesPath -ItemType Directory -Force | Out-Null
            Write-Host "  Created Obsidian: notes" -ForegroundColor Green
        }
        else {
            Write-Host "  Exists Obsidian: notes" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# === Step 6: Recreate junctions ===
Write-Host "[Step 6] Recreate Junctions" -ForegroundColor Yellow

# shared/ -> Box/Projects/{subpath}
$newSharedLink = Join-Path $dstLocal "shared"
if ($DryRun) {
    Write-Host "  [DRY] Would create junction: shared/ -> $dstBox" -ForegroundColor Magenta
}
else {
    if (Test-Path $dstBox) {
        New-Item -ItemType Junction -Path $newSharedLink -Target $dstBox | Out-Null
        Write-Host "  Created: shared/ -> $dstBox" -ForegroundColor Green
    }
    else {
        Write-Warning "  BOX folder not found: $dstBox - junction not created"
    }
}

# _ai-context/obsidian_notes/ -> Box/Obsidian-Vault/Projects/{subpath}
$newObsLink = Join-Path $dstLocal "_ai-context\obsidian_notes"
if ($DryRun) {
    Write-Host "  [DRY] Would create junction: obsidian_notes/ -> $dstObsidian" -ForegroundColor Magenta
}
else {
    if (Test-Path $dstObsidian) {
        # Ensure _ai-context exists
        $aiContextDir = Join-Path $dstLocal "_ai-context"
        if (-not (Test-Path $aiContextDir)) {
            New-Item -Path $aiContextDir -ItemType Directory -Force | Out-Null
        }
        New-Item -ItemType Junction -Path $newObsLink -Target $dstObsidian | Out-Null
        Write-Host "  Created: obsidian_notes/ -> $dstObsidian" -ForegroundColor Green
    }
    else {
        Write-Warning "  Obsidian folder not found: $dstObsidian - junction not created"
    }
}

# _ai-context/context/ -> Box/Obsidian-Vault/Projects/{subpath}/ai-context
$newContextLink = Join-Path $dstLocal "_ai-context\context"
$dstAiCtx = Join-Path $dstObsidian "ai-context"
if ($DryRun) {
    Write-Host "  [DRY] Would create junction: context/ -> $dstAiCtx" -ForegroundColor Magenta
}
else {
    if (Test-Path $dstAiCtx) {
        $aiContextDir = Join-Path $dstLocal "_ai-context"
        if (-not (Test-Path $aiContextDir)) {
            New-Item -Path $aiContextDir -ItemType Directory -Force | Out-Null
        }
        New-Item -ItemType Junction -Path $newContextLink -Target $dstAiCtx | Out-Null
        Write-Host "  Created: context/ -> $dstAiCtx" -ForegroundColor Green
    }
    else {
        Write-Warning "  Obsidian ai-context folder not found: $dstAiCtx - junction not created"
    }
}

# Skill junctions (.claude, .codex, .gemini) -> Box/Projects/{subpath}/.xxx
foreach ($cli in @(".claude", ".codex", ".gemini")) {
    $localCliPath = Join-Path $dstLocal $cli
    $boxCliPath = Join-Path $dstBox $cli
    if ($DryRun) {
        if (Test-Path $boxCliPath) {
            Write-Host "  [DRY] Would create junction: $cli -> $boxCliPath" -ForegroundColor Magenta
        }
    }
    else {
        if (Test-Path $boxCliPath) {
            New-Item -ItemType Junction -Path $localCliPath -Target $boxCliPath | Out-Null
            Write-Host "  Created: $cli -> $boxCliPath" -ForegroundColor Green
        }
    }
}
Write-Host ""

# === Step 7: Recreate AI instruction file copies ===
Write-Host "[Step 7] Recreate AI Instruction Files" -ForegroundColor Yellow

$boxAgents = Join-Path $dstBox "AGENTS.md"

if ($DryRun) {
    if (Test-Path $boxAgents) {
        Write-Host "  [DRY] Would copy: AGENTS.md (BOX -> Local)" -ForegroundColor Magenta
        Write-Host "  [DRY] Would copy: CLAUDE.md (BOX -> Local)" -ForegroundColor Magenta
    }
    else {
        Write-Host "  [DRY] AGENTS.md not found on BOX - would create default" -ForegroundColor Magenta
    }
}
else {
    if (-not (Test-Path $boxAgents)) {
        Write-Host "  AGENTS.md not found on BOX. Creating default file..." -ForegroundColor Cyan
        $defaultContent = "# Project: $ProjectName`n`nSee _ProjectTemplate/AGENTS.md for full template."
        New-Item -Path $boxAgents -ItemType File -Value $defaultContent -Force | Out-Null
        Write-Host "  Created: $boxAgents" -ForegroundColor Green
    }

    # Ensure CLAUDE.md exists on BOX
    $boxClaude = Join-Path $dstBox "CLAUDE.md"
    if (-not (Test-Path $boxClaude)) {
        Copy-Item -Path $boxAgents -Destination $boxClaude -Force
        Write-Host "  Created: BOX CLAUDE.md (Copy of AGENTS.md)" -ForegroundColor Green
    }

    # Copy to local
    $localAgents = Join-Path $dstLocal "AGENTS.md"
    $localClaude = Join-Path $dstLocal "CLAUDE.md"
    Copy-Item -Path $boxAgents -Destination $localAgents -Force
    Write-Host "  Copied: AGENTS.md -> Local Project Root" -ForegroundColor Green
    Copy-Item -Path $boxAgents -Destination $localClaude -Force
    Write-Host "  Copied: CLAUDE.md -> Local Project Root" -ForegroundColor Green
}
Write-Host ""

# === Summary ===
if ($DryRun) {
    Write-Host "=== DRY RUN Complete ===" -ForegroundColor Magenta
    Write-Host "No changes were made. Remove -DryRun to execute." -ForegroundColor Magenta
}
else {
    Write-Host "=== Conversion Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Converted: $ProjectName ($fromTier -> $toTier)" -ForegroundColor Cyan
    Write-Host "  Layer 1: $dstLocal" -ForegroundColor Gray
    Write-Host "  Layer 3: $dstBox" -ForegroundColor Gray
    Write-Host "  Layer 2: $dstObsidian" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    if ($To -eq "mini") {
        Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName -Mini"
    }
    else {
        Write-Host "  1. Run .\check_project.ps1 -ProjectName $ProjectName"
    }
    Write-Host "  2. Verify project files are accessible"
    Write-Host "  3. Update 00_Projects-Index.md if needed"
}
Write-Host ""
