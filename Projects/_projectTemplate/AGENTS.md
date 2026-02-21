# {{PROJECT_NAME}} - AI Agent Instructions

## Project Overview
- **Project**: {{PROJECT_NAME}}
- **Structure**: {{STRUCTURE_TYPE}}
- **Created**: {{CREATION_DATE}}

## IMPORTANT: Context Path
**ALL AGENTS MUST READ CONTEXT FROM: `_ai-context/context/`**
The directory `_ai-context/` contains junctions to BOX/Obsidian.
- **Do not use**: `.claude/context` (Legacy path, deprecated)
- **Use**: `_ai-context/context/` for AI context files (project_summary, current_focus, decision_log)
- **Use**: `_ai-context/obsidian_notes/` for accessing full Obsidian Knowledge Layer

## Directory Structure

### Local Folders (Documents/Projects/{{PROJECT_NAME}}/)
```
├── _ai-context/          # Shared AI Context (Read from here!)
│   ├── context/          # Junction to Box/Obsidian-Vault/.../ai-context/
│   └── obsidian_notes/   # Junction to Box/Obsidian-Vault/...
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

## Context Compression Layer

### 初回読み込み（自動）

このプロジェクトで最初のタスクに取りかかる前に、以下を読んでください:

1. `_ai-context/context/project_summary.md` - プロジェクト全体像
2. `_ai-context/context/current_focus.md` - 現在のフォーカス
3. `_ai-context/context/decision_log/` の最新3件（日付降順）

current_focus.md の末尾「更新」日付が3日以上前の場合、1回だけ聞いてください:
「前回から何か進展や変更はありましたか？（なければそのまま作業に入ります）」
回答があれば current_focus.md に反映してから作業開始。なければそのまま開始。

### 作業中

重要な意思決定（技術選定、設計判断、方針変更）があったら、1行で提案してください:
「💡 Decision Logに記録しますか？ → {決定の要約}」
承認されたら `_ai-context/context/decision_log/YYYY-MM-DD_topic.md` をTEMPLATEに従い作成。
1セッションで最大3回まで。断られたらそれ以上勧めない。

### 作業の区切り

まとまった作業が一段落したら、AI作業分を current_focus.md に追記提案してください:
- 既存の内容は触らない
- AIが追記する行には [AI] をつける
- 3-5行以内で簡潔に
- 短い質問応答だけの場合は提案不要

### Project Memory

価値のある知見を発見したら、`_ai-context/context/memories/` に保存してください:
- 「覚えておいて」「この知見を記録」などのトリガー
- 先回りして保存も推奨
- search: `rg "^summary:" _ai-context/context/memories/`

## Notes

- Use `shared/` junction to access Box shared folders
- Use `_ai-context/context/` for AI context files (BOX-synced via Obsidian)
- Use `_ai-context/obsidian_notes/` for full Obsidian note access
- Asana sync is managed globally via `_globalScripts/sync_from_asana.py`
- Environment variables in `scripts/config/.env` (not committed to git)
