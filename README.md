# ai-collab-folder-structure

![Workspace Architecture](_asset/ai-collab-folder-structure.drawio.svg)

> 🌐 [日本語版はこちら / Japanese version available here](README-ja.md)

A project folder management framework designed for collaboration with AI (Claude Code).

## Overview

A three-layer workspace structure for organizing multiple projects and optimizing context sharing with AI.

- **Layer 1 (Execution)**: Local workspace (Git-managed, volatile work)
- **Layer 2 (Knowledge)**: Obsidian Vault (accumulation of thoughts and insights, BOX sync)
- **Layer 3 (Artifact)**: Deliverables and reference materials (team sharing, BOX sync)

## Three-Layer Structure

| Layer | Role | Location | Data Characteristics |
|-------|------|----------|---------------------|
| Layer 1: Execution | Workspace | Documents/Projects/{Project}/ (Local) | WIP, highly volatile |
| Layer 2: Knowledge | Thinking & Knowledge | Box/Obsidian-Vault/ (BOX Sync) | Context, history, insights |
| Layer 3: Artifact | Deliverables & References | Box/Projects/{Project}/ (BOX Sync) | Team shared documents |

## Features

### Built-in AI Collaboration Design

- `.claude/context/` - Aggregates context for AI reference
- `CLAUDE.md` - Project-specific AI instructions (physical file on BOX side, symlinked locally)
- Knowledge base linkage via junction points

### Two Project Tiers

| Tier | Location | Purpose | Structure |
|------|----------|---------|-----------|
| full | `Projects/{Project}/` | Main projects | Full features (_ai-workspace, structured folders) |
| light | `Projects/_support/{Project}/` | Support tasks | Lightweight (minimal folders) |

### Structure Options for Full Tier

For full tier, you can choose between two document structures on the BOX side (Layer 3):

| Structure | Description |
|-----------|-------------|
| new (default) | Purpose-based classification (docs/reference/records) |
| legacy | Phase number-based (01_planning ~ 10_reference) |

### Sync Strategy Between 2 PCs

- **BOX sync**: Obsidian Vault, deliverables via shared/
- **Git sync**: Source code (development/source/)
- **Local independent**: .claude/, _ai-workspace/

## Overall Workspace Structure

```
Documents/Projects/
├── _config/
│   └── paths.json              # Workspace common path definitions
├── _projectTemplate/           # Project template and management scripts
│   ├── scripts/
│   │   ├── project_launcher.ps1    # GUI launcher
│   │   ├── setup_project.ps1       # Project initial setup
│   │   ├── check_project.ps1       # Health check
│   │   ├── archive_project.ps1     # Archive completed projects
│   │   ├── config.template.json    # Config file template
│   │   └── _exec_project_launcher.cmd  # GUI launcher batch
│   ├── CLAUDE.md               # CLAUDE.md template for new projects
│   └── README.md               # Template detailed documentation
├── _globalScripts/             # Cross-project scripts
│   ├── sync_from_asana.py      # Asana → Markdown sync
│   └── config.json.example     # Asana sync config example
├── _archive/                   # Archived projects
│   └── _support/               # Archived light tier projects
├── _support/                   # Light tier projects
├── _ai-workspace/              # AI analysis and experimentation for entire workspace
├── CLAUDE.md                   # AI instructions for entire workspace
├── README.md                   # This file
├── workspace-architecture.md   # Detailed design documentation
└── {ProjectName}/              # Individual projects (full tier)
```

## Project Folder Structure

### Full Tier

```
Documents/Projects/{ProjectName}/
├── .claude/                    # AI dedicated area [Local]
│   └── context/
│       └── obsidian_notes/     # Junction → Box/Obsidian-Vault/Projects/{ProjectName}
├── _ai-workspace/              # AI analysis and experimentation [Local]
├── development/                # Development related [Local - Git managed]
│   ├── source/                 # Source code
│   ├── config/                 # Configuration files
│   └── scripts/                # Development scripts
├── scripts/                    # Project management scripts [Local]
│   ├── config.json             # Project configuration
│   └── config/                 # Additional config files
├── shared/                     # Junction → Box/Projects/{ProjectName}
└── CLAUDE.md                   # Symlink → Box/Projects/{ProjectName}/CLAUDE.md

Box/Projects/{ProjectName}/         (new structure)
├── CLAUDE.md                   # AI instructions (physical file)
├── docs/                       # Created/edited documents
│   ├── planning/               # Planning, requirements, proposals
│   ├── design/                 # Design documents
│   ├── testing/                # Test plans, cases, results
│   └── release/                # Release and migration procedures
├── reference/                  # Reference materials (read-only, for storage)
│   ├── vendor/                 # Vendor-provided materials
│   ├── standards/              # Company rules and standards
│   └── external/               # Other external materials
├── records/                    # Records and history (evidence)
│   ├── minutes/                # Meeting minutes
│   ├── reports/                # Progress reports
│   └── reviews/                # Review records
└── _work/                      # Date-based working folders
```

### Light Tier

```
Documents/Projects/_support/{ProjectName}/
├── .claude/                    # AI dedicated area [Local]
│   └── context/
│       └── obsidian_notes/     # Junction → Box/Obsidian-Vault/Projects/_support/{ProjectName}
├── development/                # Development related [Local]
│   ├── source/                 # Source code (Git managed)
│   ├── config/                 # Configuration files
│   └── scripts/                # Development scripts
├── scripts/                    # Project management scripts [Local]
│   └── config.json             # Project configuration (includes tier info)
├── shared/                     # Junction → Box/Projects/_support/{ProjectName}
└── CLAUDE.md                   # Symlink → Box/Projects/_support/{ProjectName}/CLAUDE.md

Box/Projects/_support/{ProjectName}/
├── CLAUDE.md                   # AI instructions (physical file)
├── docs/                       # Documents (flat - no subfolders)
└── _work/                      # Working folder
```

## Link Configuration

| Type | Local Side | Link Destination (BOX Side) | Admin Rights |
|------|-----------|----------------------------|-------------|
| Junction | shared/ | Box/Projects/{ProjectName}/ | Not required |
| Junction | .claude/context/obsidian_notes/ | Box/Obsidian-Vault/Projects/{ProjectName}/ | Not required |
| Symlink | CLAUDE.md | Box/Projects/{ProjectName}/CLAUDE.md | Required (Developer Mode) |

## Quick Start

### 1. Prerequisites

Create `Documents/Projects/_config/paths.json`:

```json
{
  "localProjectsRoot": "Documents\\Projects",
  "boxProjectsRoot": "Box\\Projects",
  "obsidianVaultRoot": "Box\\Obsidian-Vault"
}
```

Each value is a relative path from `%USERPROFILE%`.

To create symbolic links for CLAUDE.md, Developer Mode must be enabled:
- Windows Settings → System → For developers → Developer Mode ON (recommended)
- Or run scripts with administrator privileges

### 2. Using GUI Launcher (Recommended)

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\project_launcher.ps1"
```

Or double-click `_projectTemplate\scripts\_exec_project_launcher.cmd` to launch.

Features:
- Setup tab: Select project name, Structure, and Tier for setup
- Check tab: Health check for existing projects
- Archive tab: Archive with DryRun preview
- Real-time display of script output

### 3. Command Line Operation

```powershell
# Main project (full tier, new structure - default)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject"

# Main project (full tier, legacy structure)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject" -Structure legacy

# Support task (light tier)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "SupportProject" -Tier light
```

### 4. Health Check

```powershell
# Main project
.\_projectTemplate\scripts\check_project.ps1 -ProjectName "NewProject"

# Support task
.\_projectTemplate\scripts\check_project.ps1 -ProjectName "SupportProject" -Support
```

### 5. Archiving Projects

```powershell
# Check with DryRun (no actual changes)
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "MyProject" -DryRun

# Execute
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "MyProject"

# Support task
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "SupportProject" -Support -DryRun
```

Archiving moves all three layers to `_archive/`. Light tier projects are moved under `_archive/_support/`.

### 6. Setup on PC-B

After BOX sync is complete, simply run the same script to create junctions and symbolic links:

```powershell
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject"
```

- `_config/paths.json` must be created individually on each PC (not BOX synced)
- CLAUDE.md is already BOX synced, so only the symbolic link is created

## Script List

### _projectTemplate/scripts/

| Script | Purpose |
|--------|---------|
| `project_launcher.ps1` | GUI launcher (integrates all scripts) |
| `setup_project.ps1` | Project initial setup |
| `check_project.ps1` | Health check |
| `archive_project.ps1` | Archive completed projects |
| `config.template.json` | Config file template |
| `_exec_project_launcher.cmd` | GUI launcher batch file |

### _globalScripts/

| Script | Purpose |
|--------|---------|
| `sync_from_asana.py` | Asana tasks → Markdown sync |
| `config.json.example` | Asana sync config file example |

## Documentation

- [workspace-architecture.md](workspace-architecture.md) - Detailed design documentation
- [_projectTemplate/README.md](_projectTemplate/README.md) - Template detailed documentation
- [CLAUDE.md](CLAUDE.md) - AI instructions for entire workspace

## Limitations

- Windows only (junctions and PowerShell scripts)
- BOX Drive required (Layer 2/3 sync)
- Junctions only work within the same volume
- .ps1 scripts are written in Shift_JIS (cp932), output is UTF-8
- Creating symlinks for CLAUDE.md requires Developer Mode or administrator privileges
- Obsidian Vault should not be opened on two PCs simultaneously (to prevent data overwrite)

## License

MIT License
