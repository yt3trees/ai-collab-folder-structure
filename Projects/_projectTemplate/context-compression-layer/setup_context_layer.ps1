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
    [ValidateSet("project", "domain")]
    [string]$Category = "project",
    [string]$TemplateDir
)

$configPath = Join-Path $env:USERPROFILE "Documents\Projects\_config\paths.json"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] paths.json not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$projectsRoot = [System.Environment]::ExpandEnvironmentVariables($config.localProjectsRoot)
$boxProjectsRoot = [System.Environment]::ExpandEnvironmentVariables($config.boxProjectsRoot)
$obsidianVaultRoot = [System.Environment]::ExpandEnvironmentVariables($config.obsidianVaultRoot)

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

    # Global AI Context (Obsidian Vault)
    $globalAiCtx = Join-Path $obsidianVaultRoot "ai-context"
    $techPatterns = Join-Path $globalAiCtx "tech-patterns"
    $lessonsLearned = Join-Path $globalAiCtx "lessons-learned"
    Ensure-Dir $globalAiCtx
    Ensure-Dir $techPatterns
    Ensure-Dir $lessonsLearned
}



# --- Per-project setup ---
function Setup-Project {
    param([string]$Name, [switch]$IsMini, [string]$Category = "project")

    $categoryPrefix = if ($Category -eq "domain") { "_domains\" } else { "" }
    if ($IsMini) {
        $dir = Join-Path $projectsRoot "${categoryPrefix}_mini\$Name"
        $obsidianSubPath = "${categoryPrefix}_mini\$Name"
    }
    else {
        $dir = Join-Path $projectsRoot "${categoryPrefix}$Name"
        $obsidianSubPath = "${categoryPrefix}$Name"
    }

    if (-not (Test-Path $dir)) {
        Write-Host "[ERROR] Project not found: $dir" -ForegroundColor Red
        return
    }

    Write-Host "`n=== Project: $Name ===" -ForegroundColor Cyan

    # Files live in Obsidian ai-context/ folder (BOX-synced, accessed via context/ junction)
    $obsAiCtx = Join-Path $obsidianVaultRoot "Projects\$obsidianSubPath\ai-context"
    $dlDir = Join-Path $obsAiCtx "decision_log"
    $fhDir = Join-Path $obsAiCtx "focus_history"
    Ensure-Dir $obsAiCtx
    Ensure-Dir $dlDir
    Ensure-Dir $fhDir

    Copy-IfNotExists (Join-Path $TemplateDir "project_summary.md")    (Join-Path $obsAiCtx "project_summary.md")
    Copy-IfNotExists (Join-Path $TemplateDir "current_focus.md")      (Join-Path $obsAiCtx "current_focus.md")
    Copy-IfNotExists (Join-Path $TemplateDir "decision_log_TEMPLATE.md") (Join-Path $dlDir "TEMPLATE.md")
    Copy-IfNotExists (Join-Path $TemplateDir "file_map.md")           (Join-Path $obsAiCtx "file_map.md")
    Copy-IfNotExists (Join-Path $TemplateDir "tensions.md")           (Join-Path $obsAiCtx "tensions.md")

    # Ensure context/ junction exists (_ai-context/context/ -> Obsidian ai-context/)
    $aiContextDir = Join-Path $dir "_ai-context"
    $contextJunction = Join-Path $aiContextDir "context"
    Ensure-Dir $aiContextDir
    if (Test-Path $contextJunction) {
        Write-Host "  [SKIP]   context/ junction (already exists)" -ForegroundColor Yellow
    }
    elseif (Test-Path $obsAiCtx) {
        cmd /c mklink /J "$contextJunction" "$obsAiCtx" | Out-Null
        Write-Host "  [CREATE] context/ -> $obsAiCtx (junction)" -ForegroundColor Green
    }
    else {
        Write-Host "  [WARN]   context/ junction not created (Obsidian ai-context not found)" -ForegroundColor Yellow
    }

    # Auto-append CCL instructions to CLAUDE.md and AGENTS.md
    $snippetPath = Join-Path $TemplateDir "CLAUDE_MD_SNIPPET.md"
    foreach ($mdFile in @("CLAUDE.md", "AGENTS.md")) {
        $pathsToCheck = @(
            (Join-Path $dir $mdFile),
            (Join-Path $dir "shared\$mdFile")
        )
        foreach ($mdPath in $pathsToCheck) {
            $displayPath = if ($mdPath -match 'shared\\') { "shared\$mdFile" } else { $mdFile }
            
            if ((Test-Path $mdPath) -and (Test-Path $snippetPath)) {
                $mdContent = Get-Content $mdPath -Raw -Encoding UTF8
                if ($mdContent -notlike "*## Context Compression Layer*") {
                    $snippetContent = Get-Content $snippetPath -Raw -Encoding UTF8
                    if ($snippetContent -match '(?s)```markdown\r?\n(.*?)\r?\n```') {
                        $cclSection = $Matches[1]
                        Add-Content -Path $mdPath -Value "`n$cclSection" -Encoding UTF8
                        Write-Host "  [UPDATE] $displayPath <- CCL instructions appended" -ForegroundColor Green
                    }
                }
                else {
                    Write-Host "  [SKIP]   $displayPath (CCL already included)" -ForegroundColor Yellow
                }
            }
            elseif (-not (Test-Path $mdPath)) {
                Write-Host "  [INFO]   $displayPath not found, skipping CCL append" -ForegroundColor DarkGray
            }
        }
    }

    # --- Skills setup (Per-Project) ---
    if (Test-Path $SkillsDir) {
        $skillFolders = Get-ChildItem -Path $SkillsDir -Directory
        if ($skillFolders.Count -gt 0) {
            # Determine BOX project path
            if ($IsMini) {
                $boxProjDir = Join-Path $boxProjectsRoot "${categoryPrefix}_mini\$Name"
            }
            else {
                $boxProjDir = Join-Path $boxProjectsRoot "${categoryPrefix}$Name"
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
    Setup-Project -Name $ProjectName -IsMini:$Mini -Category $Category
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Write your current focus in current_focus.md" -ForegroundColor White
Write-Host "  2. Fill in project_summary.md (you can ask AI to draft it)" -ForegroundColor White
Write-Host "  3. Update file_map.md to reflect actual project structure" -ForegroundColor White
