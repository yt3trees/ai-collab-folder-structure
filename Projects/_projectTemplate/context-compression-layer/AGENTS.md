# AGENTS.md - Context Compression Layer

This file provides guidance for AI agents operating in this repository.

## Project Overview

This is the Context Compression Layer (CCL) - a methodology and toolset for managing AI context across sessions. It provides:
- PowerShell scripts for setting up and maintaining context files
- Templates for project_summary.md, current_focus.md, decision_log
- Claude Code skills for automatic context management

## Directory Structure

```
context-compression-layer/
├── setup_context_layer.ps1    # Main setup script
├── save_focus_snapshot.ps1    # Daily snapshot script
├── templates/                 # Template files
│   ├── CLAUDE_MD_SNIPPET.md  # CCL instructions for CLAUDE.md
│   ├── current_focus.md
│   ├── project_summary.md
│   ├── decision_log_TEMPLATE.md
│   └── file_map.md
├── skills/                   # Claude Code skills
│   ├── context-init/
│   ├── context-session-end/
│   └── context-decision-log/
└── examples/                 # Example files
```

## Running Scripts

### Setup Script
```powershell
# Setup with workspace + specific project
.\setup_context_layer.ps1 -ProjectName "ProjectName"

# Setup for Mini Tier project
.\setup_context_layer.ps1 -ProjectName "SupportTask" -Mini

# Workspace only (no project)
.\setup_context_layer.ps1
```

### Save Focus Snapshot
```powershell
# Save project snapshot
.\save_focus_snapshot.ps1 -ProjectName "ProjectName"

# Save workspace snapshot
.\save_focus_snapshot.ps1 -Workspace

# Mini tier project
.\save_focus_snapshot.ps1 -ProjectName "Task" -Mini
```

## PowerShell Code Style

Follow the PowerShell Quality Skill guidelines. Key points:

### Encoding
- **.ps1 files**: Save as **Shift_JIS (SJIS)** if containing Japanese
- **Output files** (logs, CSV): Use **UTF-8** with `-Encoding utf8`

### Script Header
All scripts must have a comment-based header:
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER ParamName
    Parameter description
.EXAMPLE
    .\Script.ps1 -ParamName "value"
#>

param(
    [string]$ParamName
)
```

### Error Handling
- Use `$ErrorActionPreference = 'Stop'` at script start
- Wrap main logic in try-catch-finally
- Include meaningful error messages with `$_.Exception.Message`

### File Operations
```powershell
# Always specify encoding
Get-Content $path -Encoding UTF8
Set-Content -Path $path -Value $content -Encoding UTF8
Out-File -FilePath $path -Encoding utf8

# Test paths before use
if (-not (Test-Path $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}
```

### Variable Naming
- Use PascalCase: `$ProjectName`, `$ConfigPath`
- Use descriptive names: `$projectsRoot`, `$obsidianVaultRoot`
- Avoid abbreviations unless well-known: `$ctx` is OK, `$cfg` is not

### Parameter Design
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [switch]$Mini
)
```

## Markdown Template Conventions

### current_focus.md
- Keep 10-20 lines as a snapshot of current state
- Human authors primary content
- AI suggests `[AI]` tagged additions at work boundaries
- Update "更新:" date when modified

### project_summary.md
- Project overview (1-2 pages)
- Created by humans, AI can propose updates
- Include: goals, status, key files, stakeholders

### decision_log/*.md
- Format: `YYYY-MM-DD_topic.md`
- Include: context, decision, rationale, alternatives considered
- Humans approve before saving

## No Build/Tests

This project contains only PowerShell scripts and markdown templates - there are no build steps or tests to run.

## Related Documentation

- README.md - Project overview
- README-ja.md - Japanese documentation
- templates/CLAUDE_MD_SNIPPET.md - CCL instructions to append to CLAUDE.md
