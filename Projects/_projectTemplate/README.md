# Project Template

A standard template for creating new projects.
Provides a folder structure based on the 3-layer architecture (Execution/Knowledge/Artifact) along with automation scripts.

## Overview

This template includes:

- Creation of local-only folders (_ai-workspace, development)
- Creation of BOX shared folders (auto-synced)
- Automatic junction setup (shared/, obsidian_notes/)
- Copy creation of AGENTS.md and CLAUDE.md (BOX side is the master)
- Creation of _ai-context folder and Obsidian Junction setup
- Automatic creation of Obsidian Vault project folders and Index files
- Health check functionality

## Prerequisites

### 1. Create paths.json

All scripts read path information from `_config/paths.json`.
Create the following file once during initial setup:

File: `Documents/Projects/_config/paths.json`

```json
{
  "localProjectsRoot": "%USERPROFILE%\\Documents\\Projects",
  "boxProjectsRoot": "%USERPROFILE%\\Box\\Projects",
  "obsidianVaultRoot": "%USERPROFILE%\\Box\\Obsidian-Vault"
}
```

Each value is a full path. Environment variables such as `%USERPROFILE%` are expanded automatically.
If PC-B has the same directory structure, it works as-is.
Modify the paths if the BOX sync destination differs between PCs.

### 2. Enable Developer Mode

Creating symbolic links for AGENTS.md / CLAUDE.md requires one of the following:
- Run PowerShell with administrator privileges
- Or enable Windows Developer Mode (Settings > Update & Security > For Developers)

About Obsidian Junction:
- By default, a junction is created from `_ai-context/obsidian_notes/` to BOX.

## Usage

### 1. Verify paths.json

Check that `Documents/Projects/_config/paths.json` exists.
If not, refer to the "Prerequisites" section to create it.

### 2. Use the GUI (Recommended)

The GUI launcher allows you to perform Setup / Check / Archive operations graphically.

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\project_launcher.ps1"
```

Alternatively, right-click `project_launcher.ps1` in the `_projectTemplate/scripts/` folder and select "Run with PowerShell".

Features:
- Setup tab: Select project name and Tier to run setup
- Check tab: Choose an existing project from a dropdown to run health checks
- Archive tab: Execute archiving with DryRun preview
- Output area displays script execution results in real-time

### 3. Use the Command Line

Open PowerShell and run the following commands:

```powershell
# Navigate to the template directory
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# Setup a main project (full tier)
.\setup_project.ps1 -ProjectName "MyNewProject"

# Setup a support project (mini tier)
.\setup_project.ps1 -ProjectName "SupportProject" -Tier mini
```

Parameters:
- `-ProjectName` (required): Project name
- `-Tier` (optional): `full` (default, main projects) or `mini` (support/lightweight projects)

What the script does (full tier):
1. Create local folders (_ai-context, _ai-workspace, development)
2. Create BOX shared folders (docs, reference, records, _work)
3. Create Obsidian Vault project folders (daily, meetings, specs, notes, troubleshooting) and Index files
4. Create junctions (shared/, obsidian_notes/)
5. Copy AGENTS.md/CLAUDE.md (BOX side -> local)

What the script does (mini tier):
1. Create local folders (_ai-context, development) - no _ai-workspace
2. Create BOX shared folders (docs, _work) - lightweight configuration
3. Create Obsidian Vault project folders and Index files
4. Create junctions (shared/, obsidian_notes/)
5. Copy AGENTS.md/CLAUDE.md (BOX side -> local)

### 4. Automatic AGENTS.md Creation

If `AGENTS.md` (AI instruction file) does not exist on the BOX side, the setup script automatically creates a default file.
It then copies the BOX-side file to local to create `AGENTS.md` and `CLAUDE.md`.

> Note: These are independent file copies, not symbolic links.
> If you update `AGENTS.md` on the BOX side, manually copy it to local or re-run `setup_project.ps1` to overwrite.

After creation, edit the content as needed:

```powershell
notepad "$env:USERPROFILE\Box\Projects\MyNewProject\AGENTS.md"
```

### 5. Verify the Setup

```powershell
# Verify a main project
.\check_project.ps1 -ProjectName "MyNewProject"

# Verify a support project (mini tier)
.\check_project.ps1 -ProjectName "SupportProject" -Mini
```

This script checks the following:
- Junction: Whether `shared/` and `_ai-context/obsidian_notes/` are correctly linked
- Files: Whether `AGENTS.md` and `CLAUDE.md` (copies from BOX) exist
- Shortcuts: Whether `.lnk` files are not broken

### 6. Archive Completed Projects

When a project is completed, use the following commands to move all 3 layers to `_archive/`:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# Archive a main project
# First, run DryRun to verify (no actual changes made)
.\archive_project.ps1 -ProjectName "MyProject" -DryRun

# If everything looks good, execute
.\archive_project.ps1 -ProjectName "MyProject"

# Archive a support project (mini tier)
.\archive_project.ps1 -ProjectName "SupportProject" -Mini -DryRun
.\archive_project.ps1 -ProjectName "SupportProject" -Mini
```

Parameters:
- `-ProjectName` (required): Name of the project to archive
- `-Mini` (optional): Specify for mini tier projects (under _mini/)
- `-DryRun` (optional): Only display changes without executing
- `-Force` (optional): Skip confirmation prompt

What the script does:
1. Safely remove junctions (shared/, obsidian_notes/) and AI symbolic links (AGENTS.md, CLAUDE.md)
2. Move Layer 3 (BOX artifacts) to `Box/Projects/_archive/{ProjectName}/`
   - For support projects: `Box/Projects/_archive/_mini/{ProjectName}/`
3. Move Layer 2 (Obsidian knowledge) to `Box/Obsidian-Vault/Projects/_archive/{ProjectName}/`
   - For support projects: `Box/Obsidian-Vault/Projects/_archive/_mini/{ProjectName}/`
4. Move Layer 1 (local) to `Documents/Projects/_archive/{ProjectName}/`
   - For support projects: `Documents/Projects/_archive/_mini/{ProjectName}/`
5. Prompt for manual update if references exist in `00_Projects-Index.md`

### 7. Convert Project Tier

Convert an existing project between mini and full tiers:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# Convert mini -> full (DryRun first)
.\convert_tier.ps1 -ProjectName "SupportProject" -To full -DryRun
.\convert_tier.ps1 -ProjectName "SupportProject" -To full

# Convert full -> mini
.\convert_tier.ps1 -ProjectName "MyProject" -To mini -DryRun
.\convert_tier.ps1 -ProjectName "MyProject" -To mini
```

Parameters:
- `-ProjectName` (required): Project name to convert
- `-To` (required): Target tier (`full` or `mini`)
- `-DryRun` (optional): Only display changes without executing

What the script does:
1. Remove existing junctions and AI instruction file copies
2. Move all 3 layers to the new tier location
3. Create additional folders required by the target tier
4. Recreate junctions and AI instruction file copies

> Note: Converting full -> mini does not delete full-only folders. Files in _ai-workspace/, reference/, records/, etc. are preserved.

### 8. Setup on PC-B

On PC-B, after BOX sync is complete, simply run the same script to set up the environment:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# Create paths.json on each PC individually (modify only if BOX paths differ)
# Creates junctions and symbolic links
.\setup_project.ps1 -ProjectName "MyNewProject"
```

- `_config/paths.json` is required on each PC (not synced via BOX)
- AGENTS.md is already synced via BOX, so only symbolic links are created
- Junctions are local-only, so they must be created on each PC

## Project Tiers

Two tier types are available based on project scale and involvement level.

| Tier | Location | Purpose | Configuration |
|------|----------|---------|---------------|
| full | `Projects/{Project}/` | Main projects (full features) | All folders, all features |
| mini | `Projects/_mini/{Project}/` | Support projects (lightweight) | Minimal folders, simple |

### Folder Structure Differences by Tier

| Element | full | mini |
|---------|------|------|
| Layer 1 (_ai-context/) | Yes | Yes |
| Layer 1 (_ai-workspace/) | Yes | No |
| Layer 2 (Obsidian) | daily, meetings, specs, notes, troubleshooting | Same as full |
| Layer 3 (BOX docs/) | planning, design, testing, release | flat (no subfolders) |
| Layer 3 (reference/) | Yes (vendor, standards, external) | No |
| Layer 3 (records/) | Yes (minutes, reports, reviews) | No |
| Layer 3 (_work/) | Yes | Yes |

## Folder Structure

### full Structure

Organized by purpose:

```
Box/Projects/{ProjectName}/
├── AGENTS.md            # Project-specific AI instruction file (master copy)
├── docs/                # Documents to create and edit
│   ├── planning/        # Planning, requirements, proposals
│   ├── design/          # Design documents (basic/detailed/data model/UI)
│   ├── testing/         # Test plans, cases, results
│   └── release/         # Release and migration procedures, environment setup
│
├── reference/           # Reference materials (read-only, archival)
│   ├── vendor/          # Vendor-provided documents, specifications
│   ├── standards/       # Internal standards, guidelines
│   └── external/        # Other external materials, research results
│
├── records/             # Records and history (audit trail)
│   ├── minutes/         # Meeting minutes
│   ├── reports/         # Progress reports, stakeholder-facing
│   └── reviews/         # Review records, approval history
│
└── _work/               # Date-based working folders
    └── 2026/
        └── 01/
            └── 25_handling_XXX/
```

### mini Structure (Support Projects)

Lightweight configuration. Placed under `_mini/`.

```
Documents/Projects/_mini/{ProjectName}/
├── _ai-context/                # Common Context [Local]
│   └── obsidian_notes/         # Junction -> Box/Obsidian-Vault/Projects/_mini/{ProjectName}
├── development/                # Development-related [Local]
│   ├── source/                 # Source code (Git managed)
│   └── config/                 # Configuration files
│
├── shared/                     # Junction -> Box/Projects/_mini/{ProjectName}
├── AGENTS.md                   # Copy from shared/AGENTS.md
└── CLAUDE.md                   # Copy from shared/AGENTS.md

Box/Projects/_mini/{ProjectName}/
├── AGENTS.md                   # Project-specific AI instruction file (master copy)
├── docs/                       # Documents (flat - no subfolders)
└── _work/                      # Working folder

Box/Obsidian-Vault/Projects/_mini/{ProjectName}/
├── daily/
├── meetings/
├── notes/
├── specs/
├── troubleshooting/

├── ai-context/
└── 00_{ProjectName}-Index.md   # Project index
```

## Local Folder Structure (full tier)

```
Documents/Projects/{ProjectName}/
├── _ai-context/                # Shared AI Context (Read from here!)
│   └── obsidian_notes/         # Junction -> Box/Obsidian-Vault/Projects/{ProjectName}
│
├── _ai-workspace/              # AI analysis and experimentation [Local]
│
├── development/                # Development-related [Local]
│   ├── source/                 # Source code (Git managed)
│   ├── config/                 # Configuration files
│   └── scripts/                # Development scripts
│
├── shared/                     # Junction -> Box/Projects/{ProjectName}
├── AGENTS.md                   # Copy from shared/AGENTS.md
└── CLAUDE.md                   # Copy from shared/AGENTS.md
```

## Workspace Configuration Files

```
Documents/Projects/
├── _config/
│   └── paths.json              # Workspace-wide path definitions
├── _projectTemplate/           # This template
├── _globalScripts/             # Cross-project scripts
├── ProjectA/                   # Project A
└── ProjectB/                   # Project B
```

## Included Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `project_launcher.ps1` | GUI launcher (integrates all scripts) | `_projectTemplate/scripts/` |
| `setup_project.ps1` | Initial project setup | `_projectTemplate/scripts/` |
| `check_project.ps1` | Health check | `_projectTemplate/scripts/` |
| `archive_project.ps1` | Archive completed projects | `_projectTemplate/scripts/` |
| `convert_tier.ps1` | Convert between mini/full tiers | `_projectTemplate/scripts/` |
| `config.template.json` | Configuration file template | Copy and use |

## 3-Layer Architecture Mapping

| Layer | Role | Location | Data Characteristics |
|-------|------|----------|---------------------|
| Layer 1: Execution | Workspace | Documents/Projects/{ProjectName}/ (Local) | WIP, highly volatile |
| Layer 2: Knowledge | Thinking/Knowledge | Box/Obsidian-Vault/ (BOX Sync) | Context, history, insights |
| Layer 3: Artifact | Deliverables/References | Box/Projects/{ProjectName}/ (BOX Sync) | Team-shared documents |

## Link Configuration Summary

| Type | Local Side | -> | BOX Side (Source) | BOX Sync | Admin Required |
|------|-----------|-----|-------------------|----------|----------------|
| Junction | shared/ | -> | Box/Projects/{ProjectName}/ | - | No |
| Junction | _ai-context/obsidian_notes/ | -> | Box/Obsidian-Vault/Projects/{ProjectName}/ | - | No |
| Copy | AGENTS.md | <- | Box/Projects/{ProjectName}/AGENTS.md | Source is synced (Master) | No |
| Copy | CLAUDE.md | <- | Box/Projects/{ProjectName}/AGENTS.md | Copy for Claude | No |

## Obsidian Vault Integration

The following are automatically created during setup:

- `shared/` -> `Box/Projects/{ProjectName}/` (deliverables)
- `_ai-context/obsidian_notes/` -> `Box/Obsidian-Vault/Projects/{ProjectName}/` (knowledge base)
- Project folders within Obsidian Vault (daily, meetings, specs, notes, troubleshooting)
- `00_{ProjectName}-Index.md`

Create the following files in Obsidian:

- `Projects/{ProjectName}/00_{ProjectName}-Index.md` (project home page)
- `Projects/{ProjectName}/daily/YYYY-MM-DD.md` (daily notes)

## Important Notes

- Do not modify this template itself
- Always run scripts from this template when creating new projects
- The `shared/` folder is a junction to Box. Do not commit its contents directly
- Do not open Obsidian Vault on two PCs simultaneously (to prevent data overwrites)
- Place Git repositories in `development/source/` and do not sync `.git/` via BOX
- `_config/paths.json` is not synced via BOX. It must be created individually on each PC

## Troubleshooting

### paths.json Not Found

If you get a "Paths config not found" error when running scripts:

```powershell
# Check if the _config folder exists
Test-Path "$env:USERPROFILE\Documents\Projects\_config\paths.json"

# If not, create it (refer to the "Prerequisites" section)
```

### Junctions Not Created

Verify that Box sync is complete:
```powershell
Test-Path "$env:USERPROFILE\Box\Projects\{ProjectName}"
```

### AI Instruction Files (AGENTS.md / CLAUDE.md) Not Updated

- Cause: Since file copies (not symbolic links) are used, changes on the BOX side are not reflected locally.
- Solution: Edit the local file directly, or manually copy from BOX after editing.

### Manual Symbolic Link Creation (Reference)

```powershell
# AGENTS.md (Local -> Box)
New-Item -ItemType SymbolicLink -Path "Documents\Projects\{ProjectName}\AGENTS.md" -Target "Box\Projects\{ProjectName}\AGENTS.md"
# CLAUDE.md (Local -> Local AGENTS.md)
cd Documents\Projects\{ProjectName}
New-Item -ItemType SymbolicLink -Path "CLAUDE.md" -Target "AGENTS.md"
```

### Configuration File Not Found

`scripts/config.json` is a configuration file referenced by `check_project.ps1`. Create it manually or refer to `config.template.json`.

### Obsidian Integration Not Working

Verify the Obsidian Vault path is correct:
```powershell
Test-Path "$env:USERPROFILE\Box\Obsidian-Vault\Projects\{ProjectName}"
```

## Related Documents

- `AGENTS.md` - AGENTS.md template for this project template
- `_config/paths.json` - Workspace-wide path definitions
- `workspace-architecture.md` - Detailed design document
- `_globalScripts/sync_from_asana.py` - Asana integration script
