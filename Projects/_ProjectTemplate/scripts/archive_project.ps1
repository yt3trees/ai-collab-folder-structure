# Project Archive Script
# Moves a completed project to _archive/ folders across all 3 layers
# Usage: .\archive_project.ps1 -ProjectName "ProjectName" [-Mini] [-DryRun]
#
# What this script does:
#   1. Removes junctions (shared/, obsidian_notes/) and AI symlinks safely
#   2. Moves Layer 3 (BOX Artifact) to Box/Projects/_archive/{ProjectName}/
#   3. Moves Layer 2 (Obsidian Knowledge) to Box/Obsidian-Vault/Projects/_archive/{ProjectName}/
#   4. Moves Layer 1 (Local Execution) to Documents/Projects/_archive/{ProjectName}/
#   5. Updates 00_Projects-Index.md (if exists)
#
# Safety:
#   - Junctions are removed BEFORE moving folders (prevents data loss)
#   - DryRun mode shows what would happen without making changes
#   - Confirmation prompt before execution (unless -Force)

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$false)]
    [switch]$Mini,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
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

$localProjectsRoot = Join-Path $env:USERPROFILE $pathsConfig.localProjectsRoot
$boxProjectsRoot = Join-Path $env:USERPROFILE $pathsConfig.boxProjectsRoot
$obsidianVaultRoot = Join-Path $env:USERPROFILE $pathsConfig.obsidianVaultRoot

# Determine project subpath based on Support flag
if ($Mini) {
    $projectSubPath = "_mini\$ProjectName"
    $archiveSubPath = "_archive\_mini\$ProjectName"
} else {
    $projectSubPath = $ProjectName
    $archiveSubPath = "_archive\$ProjectName"
}

# Source paths
$docRoot = Join-Path $localProjectsRoot $projectSubPath
$boxShared = Join-Path $boxProjectsRoot $projectSubPath
$obsidianProject = Join-Path $obsidianVaultRoot "Projects\$projectSubPath"

# Archive destinations
$localArchive = Join-Path $localProjectsRoot $archiveSubPath
$boxArchive = Join-Path $boxProjectsRoot $archiveSubPath
$obsidianArchive = Join-Path $obsidianVaultRoot "Projects\$archiveSubPath"

# Obsidian index file
$projectsIndex = Join-Path $obsidianVaultRoot "Projects\00_Projects-Index.md"

# --- Header ---
Write-Host ""
Write-Host "=== Archive Project: $ProjectName ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "[DRY RUN] No changes will be made" -ForegroundColor Magenta
}
Write-Host ""

# --- Validation ---
$projectExists = $false

if (Test-Path $docRoot) {
    Write-Host "  Layer 1 (Local):    $docRoot" -ForegroundColor Gray
    $projectExists = $true
} else {
    Write-Host "  Layer 1 (Local):    Not found" -ForegroundColor DarkYellow
}

if (Test-Path $boxShared) {
    Write-Host "  Layer 3 (BOX):      $boxShared" -ForegroundColor Gray
    $projectExists = $true
} else {
    Write-Host "  Layer 3 (BOX):      Not found" -ForegroundColor DarkYellow
}

if (Test-Path $obsidianProject) {
    Write-Host "  Layer 2 (Obsidian): $obsidianProject" -ForegroundColor Gray
    $projectExists = $true
} else {
    Write-Host "  Layer 2 (Obsidian): Not found" -ForegroundColor DarkYellow
}

if (-not $projectExists) {
    Write-Error "Project '$ProjectName' not found in any layer."
    exit 1
}

Write-Host ""
Write-Host "Archive destinations:" -ForegroundColor Yellow
Write-Host "  Layer 1 -> $localArchive" -ForegroundColor Gray
Write-Host "  Layer 3 -> $boxArchive" -ForegroundColor Gray
Write-Host "  Layer 2 -> $obsidianArchive" -ForegroundColor Gray
Write-Host ""

# --- Check for conflicts ---
$conflicts = @()
if (Test-Path $localArchive) { $conflicts += "Local: $localArchive" }
if (Test-Path $boxArchive) { $conflicts += "BOX: $boxArchive" }
if (Test-Path $obsidianArchive) { $conflicts += "Obsidian: $obsidianArchive" }

if ($conflicts.Count -gt 0) {
    Write-Host "Archive destination already exists:" -ForegroundColor Red
    foreach ($c in $conflicts) {
        Write-Host "  - $c" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please remove or rename the existing archive folder before proceeding." -ForegroundColor DarkYellow
    exit 1
}

# --- Confirmation ---
if (-not $DryRun -and -not $Force) {
    Write-Host "This will archive '$ProjectName' by:" -ForegroundColor Yellow
    Write-Host "  1. Removing junctions and symlinks (safe - does not delete target data)" -ForegroundColor Gray
    Write-Host "  2. Moving all 3 layers to _archive/ folders" -ForegroundColor Gray
    Write-Host ""
    $response = Read-Host "Continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor DarkYellow
        exit 0
    }
    Write-Host ""
}

# --- Helper function ---
function Remove-JunctionSafely {
    param([string]$Path, [string]$Label)

    if (-not (Test-Path $Path)) {
        Write-Host "  Skip: $Label (not found)" -ForegroundColor Gray
        return
    }

    $item = Get-Item $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if ($DryRun) {
            Write-Host "  [DRY] Would remove junction: $Label" -ForegroundColor Magenta
        } else {
            # Remove junction without deleting target contents
            $item.Delete()
            Write-Host "  Removed junction: $Label" -ForegroundColor Green
        }
    } else {
        Write-Warning "  $Label is not a junction/symlink (regular folder/file). Skipping removal."
        Write-Host "    Path: $Path" -ForegroundColor DarkYellow
    }
}

function Remove-SymlinkSafely {
    param([string]$Path, [string]$Label)

    if (-not (Test-Path $Path)) {
        Write-Host "  Skip: $Label (not found)" -ForegroundColor Gray
        return
    }

    $item = Get-Item $Path -Force
    if ($item.LinkType -eq 'SymbolicLink') {
        if ($DryRun) {
            Write-Host "  [DRY] Would remove symlink: $Label" -ForegroundColor Magenta
        } else {
            Remove-Item $Path -Force
            Write-Host "  Removed symlink: $Label" -ForegroundColor Green
        }
    } else {
        Write-Host "  $Label is a regular file (will be moved)" -ForegroundColor Gray
    }
}

function Move-ToArchive {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Host "  Skip: $Label (source not found)" -ForegroundColor Gray
        return
    }

    # Ensure parent _archive/ directory exists
    $archiveParent = Split-Path $Destination
    if (-not (Test-Path $archiveParent)) {
        if ($DryRun) {
            Write-Host "  [DRY] Would create: $archiveParent" -ForegroundColor Magenta
        } else {
            New-Item -Path $archiveParent -ItemType Directory -Force | Out-Null
        }
    }

    if ($DryRun) {
        Write-Host "  [DRY] Would move: $Label" -ForegroundColor Magenta
        Write-Host "    From: $Source" -ForegroundColor DarkGray
        Write-Host "    To:   $Destination" -ForegroundColor DarkGray
    } else {
        Move-Item -Path $Source -Destination $Destination -Force
        Write-Host "  Moved: $Label" -ForegroundColor Green
    }
}

# === Step 1: Remove junctions and symlinks ===
Write-Host "[Step 1] Remove junctions and symlinks" -ForegroundColor Yellow

# shared/ junction
$sharedLink = Join-Path $docRoot "shared"
Remove-JunctionSafely -Path $sharedLink -Label "shared/ junction"

# obsidian_notes/ junction
$obsidianLink = Join-Path $docRoot "_ai-context\obsidian_notes"
Remove-JunctionSafely -Path $obsidianLink -Label "obsidian_notes/ junction"

# AGENTS.md & CLAUDE.md symlinks
$agentsLink = Join-Path $docRoot "AGENTS.md"
Remove-SymlinkSafely -Path $agentsLink -Label "AGENTS.md symlink"

$claudeLink = Join-Path $docRoot "CLAUDE.md"
Remove-SymlinkSafely -Path $claudeLink -Label "CLAUDE.md symlink"

Write-Host ""

# === Step 2: Move Layer 3 (BOX Artifact) ===
Write-Host "[Step 2] Archive Layer 3 (BOX Artifact)" -ForegroundColor Yellow
Move-ToArchive -Source $boxShared -Destination $boxArchive -Label "Box/Projects/$ProjectName"
Write-Host ""

# === Step 3: Move Layer 2 (Obsidian Knowledge) ===
Write-Host "[Step 3] Archive Layer 2 (Obsidian Knowledge)" -ForegroundColor Yellow
Move-ToArchive -Source $obsidianProject -Destination $obsidianArchive -Label "Obsidian-Vault/Projects/$ProjectName"
Write-Host ""

# === Step 4: Move Layer 1 (Local Execution) ===
Write-Host "[Step 4] Archive Layer 1 (Local)" -ForegroundColor Yellow
Move-ToArchive -Source $docRoot -Destination $localArchive -Label "Documents/Projects/$ProjectName"
Write-Host ""

# === Step 5: Update Obsidian Projects Index ===
Write-Host "[Step 5] Update Projects Index" -ForegroundColor Yellow
if (Test-Path $projectsIndex) {
    if ($DryRun) {
        Write-Host "  [DRY] Would check 00_Projects-Index.md for references to $ProjectName" -ForegroundColor Magenta
    } else {
        $indexContent = Get-Content $projectsIndex -Raw -Encoding UTF8
        if ($indexContent -match $ProjectName) {
            Write-Host "  Found references to '$ProjectName' in 00_Projects-Index.md" -ForegroundColor DarkYellow
            Write-Host "  Please manually move the entry to an 'Archived' section" -ForegroundColor DarkYellow
            Write-Host "  File: $projectsIndex" -ForegroundColor DarkGray
        } else {
            Write-Host "  No references found in 00_Projects-Index.md" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Skip: 00_Projects-Index.md not found" -ForegroundColor Gray
}

# === Summary ===
Write-Host ""
if ($DryRun) {
    Write-Host "=== DRY RUN Complete ===" -ForegroundColor Magenta
    Write-Host "No changes were made. Remove -DryRun to execute." -ForegroundColor Magenta
} else {
    Write-Host "=== Archive Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Archived locations:" -ForegroundColor Cyan
    if (Test-Path $localArchive) {
        Write-Host "  Layer 1: $localArchive" -ForegroundColor Gray
    }
    if (Test-Path $boxArchive) {
        Write-Host "  Layer 3: $boxArchive" -ForegroundColor Gray
    }
    if (Test-Path $obsidianArchive) {
        Write-Host "  Layer 2: $obsidianArchive" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Post-archive checklist:" -ForegroundColor Yellow
    Write-Host "  - [ ] Update 00_Projects-Index.md (move to 'Archived' section)" -ForegroundColor Gray
    Write-Host "  - [ ] Verify Git remote has latest push" -ForegroundColor Gray
    Write-Host "  - [ ] Review TechNotes for knowledge worth extracting" -ForegroundColor Gray
    Write-Host "  - [ ] Check Asana project status" -ForegroundColor Gray
}
Write-Host ""
