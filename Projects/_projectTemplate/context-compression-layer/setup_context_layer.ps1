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
$boxProjectsRoot = Join-Path $env:USERPROFILE $config.boxProjectsRoot

if (-not $TemplateDir) {
    $TemplateDir = Join-Path $PSScriptRoot "templates"
}

$SkillsDir = Join-Path $PSScriptRoot "skills"

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
    Copy-IfNotExists (Join-Path $TemplateDir "file_map.md") (Join-Path $aiCtx "file_map.md")

    # Auto-append CCL instructions to CLAUDE.md
    $claudeMdPath = Join-Path $dir "CLAUDE.md"
    $snippetPath = Join-Path $TemplateDir "CLAUDE_MD_SNIPPET.md"
    if ((Test-Path $claudeMdPath) -and (Test-Path $snippetPath)) {
        $claudeContent = Get-Content $claudeMdPath -Raw -Encoding UTF8
        if ($claudeContent -notlike "*## Context Compression Layer*") {
            $snippetContent = Get-Content $snippetPath -Raw -Encoding UTF8
            if ($snippetContent -match '(?s)```markdown\r?\n(.*?)\r?\n```') {
                $cclSection = $Matches[1]
                Add-Content -Path $claudeMdPath -Value "`n$cclSection" -Encoding UTF8
                Write-Host "  [UPDATE] CLAUDE.md <- CCL instructions appended" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  [SKIP]   CLAUDE.md (CCL already included)" -ForegroundColor Yellow
        }
    }
    elseif (-not (Test-Path $claudeMdPath)) {
        Write-Host "  [INFO]   CLAUDE.md not found, skipping CCL append" -ForegroundColor DarkGray
    }

    # --- Skills setup (Per-Project) ---
    if (Test-Path $SkillsDir) {
        $skillFolders = Get-ChildItem -Path $SkillsDir -Directory
        if ($skillFolders.Count -gt 0) {
            # Determine BOX project path
            if ($IsMini) {
                $boxProjDir = Join-Path $boxProjectsRoot "_mini\$Name"
            }
            else {
                $boxProjDir = Join-Path $boxProjectsRoot $Name
            }

            # 1. Deploy skills to BOX
            Write-Host "`n  [Skills (BOX)]" -ForegroundColor Cyan
            Ensure-Dir $boxProjDir
            foreach ($cli in @(".claude", ".codex", ".gemini")) {
                $dstSkillsDir = Join-Path $boxProjDir "$cli\skills"
                Ensure-Dir $dstSkillsDir
                foreach ($skill in $skillFolders) {
                    $dstSkill = Join-Path $dstSkillsDir $skill.Name
                    if (-not (Test-Path $dstSkill)) {
                        Copy-Item -Path $skill.FullName -Destination $dstSkill -Recurse
                        Write-Host "    [CREATE] $cli/skills/$($skill.Name)" -ForegroundColor Green
                    }
                    else {
                        Write-Host "    [SKIP]   $cli/skills/$($skill.Name) (already exists)" -ForegroundColor Yellow
                    }
                }
            }

            # 2. Create Junctions in Local Project Folder
            Write-Host "`n  [Skills (Local Junctions)]" -ForegroundColor Cyan
            foreach ($cli in @(".claude", ".codex", ".gemini")) {
                $localPath = Join-Path $dir $cli
                $boxPath = Join-Path $boxProjDir $cli

                if (Test-Path $localPath) {
                    $item = Get-Item $localPath -Force
                    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                        Write-Host "    [SKIP]   $cli (junction)" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "    [WARN]   $cli exists as regular folder, skipping junction" -ForegroundColor Yellow
                    }
                }
                else {
                    if (Test-Path $boxPath) {
                        cmd /c mklink /J "$localPath" "$boxPath" | Out-Null
                        Write-Host "    [CREATE] $cli -> $boxPath (junction)" -ForegroundColor Green
                    }
                    else {
                        Write-Host "    [WARN]   $cli source not found in BOX: $boxPath" -ForegroundColor Red
                    }
                }
            }
        }
    }
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
Write-Host "  3. Update file_map.md to reflect actual project structure" -ForegroundColor White
