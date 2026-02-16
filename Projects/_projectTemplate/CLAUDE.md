# {{PROJECT_NAME}} - AI Agent Instructions

## Project Overview
- **Project**: {{PROJECT_NAME}}
- **Structure**: {{STRUCTURE_TYPE}}
- **Created**: {{CREATION_DATE}}

## IMPORTANT: Context Path
**ALL AGENTS MUST READ CONTEXT FROM: `_ai-context/`**
The directory `_ai-context/` contains shared knowledge, including the `obsidian_notes` junction.
- **Do not use**: `.claude/context` (Legacy path, deprecated)
- **Use**: `_ai-context/obsidian_notes/` for accessing Knowledge Layer

## Directory Structure

### Local Folders (Documents/Projects/{{PROJECT_NAME}}/)
```
├── _ai-context/          # Shared AI Context (Read from here!)
│   └── obsidian_notes/   # Junction to Box/Obsidian-Vault
├── AGENTS.md             # Symlink to Box/Projects/{{PROJECT_NAME}}/AGENTS.md
├── CLAUDE.md             # Symlink to AGENTS.md
├── development/          # Development artifacts
│   ├── source/           # Source code
│   ├── config/           # Configuration files
│   └── scripts/          # Development scripts
├── scripts/              # Project management scripts
│   ├── config.json       # Project configuration
│   ├── setup_project.ps1    # Setup script
│   └── check_project.ps1    # Health check
└── shared/               # Junction to Box/{{PROJECT_NAME}}
```

### Shared Folders (Box/Projects/{{PROJECT_NAME}}/)
```
├── AGENTS.md            # Master Instruction File
├── docs/                # Documentation
│   ├── planning/        # Planning documents
│   ├── design/          # Design documents
│   ├── testing/         # Test documents
│   └── release/         # Release notes
├── reference/           # Reference materials
│   ├── vendor/          # Vendor docs
│   ├── standards/       # Standards & guidelines
│   └── external/        # External references
├── records/             # Project records
│   ├── minutes/         # Meeting minutes
│   ├── reports/         # Reports
│   └── reviews/         # Review records
└── _work/            # Work logs
```

## Key Scripts

All scripts are located in `_projectTemplate/scripts/`.

### GUI Launcher (recommended)
```powershell
# GUI for Setup / Check / Archive
powershell -ExecutionPolicy Bypass -File "_projectTemplate\scripts\project_launcher.ps1"
```

### Setup
```powershell
# Initial project setup
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "{{PROJECT_NAME}}" -Structure new
```

### Health Check
```powershell
# Verify project structure and junctions
.\_projectTemplate\scripts\check_project.ps1 -ProjectName "{{PROJECT_NAME}}"
```

### Archive
```powershell
# Archive completed project (DryRun first)
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "{{PROJECT_NAME}}" -DryRun
```

## Notes

- Use `shared/` junction to access Box shared folders
- Use `_ai-context/obsidian_notes/` for Obsidian integration
- Asana sync is managed globally via `_globalScripts/sync_from_asana.py`
- Environment variables in `scripts/config/.env` (not committed to git)
