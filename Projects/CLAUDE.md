# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Quick Overview

`Documents/Projects` is the workspace root for managing multiple projects.

- **Layer 1 (Execution)**: `Documents/Projects/<project>/` - Workspace, local only
- **Layer 2 (Knowledge)**: `Box/Obsidian-Vault/` - Obsidian, thoughts & insights (BOX sync)
- **Layer 3 (Artifact)**: `Box/Projects/<project>/` - Deliverables & references (BOX sync)

## Project Tiers

| Tier | Location | Purpose | Structure |
|------|----------|---------|-----------|
| full | `Projects/<project>/` | Main projects (full setup) | All folders, all features |
| mini | `Projects/_mini/<project>/` | Support tasks (lightweight) | Minimal folders |

Mini tier projects are placed under `_mini/`, with `_ai-workspace/` and some Layer 2/3 folders omitted.

### Junctions (3) - full tier

```
<project>/
├── _ai-context/context/             → Box/Obsidian-Vault/Projects/<project>/ai-context/
├── _ai-context/obsidian_notes/      → Box/Obsidian-Vault/Projects/<project>/
├── shared/                          → Box/Projects/<project>/
├── development/source/              (Git-managed, not BOX-synced)
└── _ai-workspace/                   (local workspace)
```

### Junctions (3) - mini tier

```
_mini/<project>/
├── _ai-context/context/             → Box/Obsidian-Vault/Projects/_mini/<project>/ai-context/
├── _ai-context/obsidian_notes/      → Box/Obsidian-Vault/Projects/_mini/<project>/
├── shared/                          → Box/Projects/_mini/<project>/
└── development/source/              (Git-managed, not BOX-synced)
(note: no _ai-workspace/)
```

## File Placement Rules

| Purpose | Location | Notes |
|---------|----------|-------|
| Experiments / drafts | `_ai-workspace/` | full tier only |
| AI context files | `_ai-context/context/` | all tiers (BOX-synced via Obsidian ai-context/) |
| Obsidian notes access | `_ai-context/obsidian_notes/` | all tiers |
| Deliverables | `shared/docs/`, `shared/reference/`, `shared/records/` | full: structured, mini: `shared/docs/` (flat) |
| Source code | `development/source/` (Git) | all tiers |
| Obsidian notes | `Box/Obsidian-Vault/Projects/<project>/` | full: multiple folders, mini: `notes/` only |

## DON'Ts

- Do not directly edit `asana-tasks-view.md` (auto-generated)
- Do not change the structure under `shared/` without authorization
- Do not delete or move junctions

## Key Paths

- Obsidian Vault: `%USERPROFILE%\Box\Obsidian-Vault\`
- BOX Projects: `%USERPROFILE%\Box\Projects\`
- ProjectA: `ProjectA\development\source\`
- Global AI Knowledge: `{obsidianVaultRoot}\ai-context\` (paths.json 参照)
  - tech-patterns/: Cross-project reusable code/design patterns
  - lessons-learned/: Failures and insights (tagged by project)

## Scripts

### New Project Template

```powershell
# Main project (full tier)
_projectTemplate/scripts/setup_project.ps1 -ProjectName "NewProject"

# Support task (mini tier)
_projectTemplate/scripts/setup_project.ps1 -ProjectName "SupportProject" -Tier mini
```

## 2PC Sync Strategy

- BOX sync: Obsidian Vault, deliverables via shared/
- Git sync: Source code
- Local only: `_ai-context/`, `_ai-workspace/`

## Windows Notes

- .ps1: Shift_JIS (cp932), output is UTF-8
- Junctions: only work within the same volume

## Context Compression Layer

When working across projects, check `Documents/Projects/.context/active_projects.md`.
Per-project instructions are in each project's `CLAUDE.md`.
