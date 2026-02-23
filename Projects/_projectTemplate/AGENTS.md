# {{PROJECT_NAME}} - AI Agent Instructions

## Project Overview
- Project: {{PROJECT_NAME}}
- Created: {{CREATION_DATE}}

## IMPORTANT: Context Path
ALL AGENTS MUST READ CONTEXT FROM: `_ai-context/context/`
The directory `_ai-context/` contains junctions to BOX/Obsidian.
- Do not use: `.claude/context` (Legacy path, deprecated)
- Use: `_ai-context/context/` for AI context files (project_summary, current_focus, decision_log)
- Use: `_ai-context/obsidian_notes/` for accessing full Obsidian Knowledge Layer

## Directory Structure

### Local Folders (Documents/Projects/{{PROJECT_NAME}}/)
```
├── _ai-context/          # Shared AI Context (Read from here!)
│   ├── context/          # Junction to Box/Obsidian-Vault/.../ai-context/
│   └── obsidian_notes/   # Junction to Box/Obsidian-Vault/...
├── AGENTS.md             # Symlink to Box/Projects/{{PROJECT_NAME}}/AGENTS.md
├── CLAUDE.md             # Symlink to AGENTS.md
├── development/          # Development artifacts
│   └── source/           # Source code
└── shared/               # Junction to Box/{{PROJECT_NAME}}
```

### Shared Folders (Box/Projects/{{PROJECT_NAME}}/)
```
├── AGENTS.md            # Master Instruction File
├── docs/                # Documentation
├── reference/           # Reference materials
├── records/             # Project records
└── _work/               # Work logs
```

## Notes

- Use `shared/` junction to access Box shared folders
- Use `_ai-context/context/` for AI context files (BOX-synced via Obsidian)
- Use `_ai-context/obsidian_notes/` for full Obsidian note access
