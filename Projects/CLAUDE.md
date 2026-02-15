# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Quick Overview

`Documents/Projects` は複数案件を管理するワークスペースのルート。

- **Layer 1 (Execution)**: `Documents/Projects/<案件>/` - 作業場、ローカル専用
- **Layer 2 (Knowledge)**: `Box/Obsidian-Vault/` - Obsidian、思考・知見（BOX同期）
- **Layer 3 (Artifact)**: `Box/Projects/<案件>/` - 成果物・参照（BOX同期）

## Project Tiers

| Tier | 配置先 | 用途 | 構成 |
|------|--------|------|------|
| full | `Projects/<案件>/` | メイン案件 (フル構成) | 全フォルダ、全機能 |
| mini | `Projects/_mini/<案件>/` | お手伝い系 (軽量構成) | 最小限のフォルダ |

mini tier のプロジェクトは `_mini/` 配下に配置され、`_ai-workspace/` や一部の Layer 2/3 フォルダが省略されます。

### ジャンクション（2本） - full tier

```
<案件>/
├── .claude/context/obsidian_notes/  → Box/Obsidian-Vault/Projects/<案件>/
├── shared/                          → Box/Projects/<案件>/
├── development/source/              (Git管理、BOX非同期)
└── _ai-workspace/                   (ローカル作業用)
```

### ジャンクション（2本） - mini tier

```
_mini/<案件>/
├── .claude/context/obsidian_notes/  → Box/Obsidian-Vault/Projects/_mini/<案件>/
├── shared/                          → Box/Projects/_mini/<案件>/
└── development/source/              (Git管理、BOX非同期)
(注: _ai-workspace/ なし)
```

## File Placement Rules

| 用途 | 配置先 | 備考 |
|------|--------|------|
| 実験・分析・下書き | `_ai-workspace/` | full tier のみ |
| コンテキスト蓄積 | `.claude/context/` | 全 tier |
| 成果物 | `shared/docs/`, `shared/reference/`, `shared/records/` | full: 構造化, mini: `shared/docs/` (flat) |
| ソースコード | `development/source/` (Git) | 全 tier |
| Obsidianノート | `Box/Obsidian-Vault/Projects/<案件>/` | full: 複数フォルダ, mini: `notes/` のみ |

## DON'Ts

- `asana-tasks-view.md` を直接編集しない（自動生成）
- `shared/` 配下の構造を勝手に変更しない
- ジャンクションを削除・移動しない

## Key Paths

- Obsidian Vault: `%USERPROFILE%\Box\Obsidian-Vault\`
- BOX Projects: `%USERPROFILE%\Box\Projects\`
- ProjectA: `ProjectA\development\source\`

## Scripts

### Common (_globalScripts/)
- `sync_from_asana.py` - Asana → Markdown同期

### Per-Project (ProjectA/scripts/)
- `setup_junctions.ps1` - 初回セットアップ
- `check_symlinks.ps1` - 健全性チェック
- `weekly_sync.ps1` - 週次Asana同期

### New Project Template

```powershell
# メイン案件 (full tier)
_projectTemplate/scripts/setup_project.ps1 -ProjectName "NewProject"

# お手伝い系 (light tier)
_projectTemplate/scripts/setup_project.ps1 -ProjectName "SupportProject" -Tier light
```

## 2PC Sync Strategy

- BOX同期: Obsidian Vault, shared/ 経由の成果物
- Git同期: ソースコード
- ローカル独立: `.claude/`, `_ai-workspace/`

## Windows Notes

- .ps1: Shift_JIS (cp932)、出力はUTF-8
- ジャンクション: 同一ボリューム内のみ有効
