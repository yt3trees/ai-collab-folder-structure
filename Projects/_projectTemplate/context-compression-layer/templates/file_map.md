# File Map - {{PROJECT_NAME}}

<!--
  このファイルはAIエージェントが「次に読むべきファイル」を判断するための地図です。
  Tier: {{TIER}}  (full / mini)
  作成日: {{CREATION_DATE}}
  更新日: {{CREATION_DATE}}
-->

## ジャンクションマッピング

| ローカルパス | リンク先 | 説明 |
|-------------|---------|------|
| `_ai-context/context/` | `Box/Obsidian-Vault/Projects/{{PROJECT_NAME}}/ai-context/` | AIコンテキスト (Layer 2) |
| `_ai-context/obsidian_notes/` | `Box/Obsidian-Vault/Projects/{{PROJECT_NAME}}/` | Obsidian ノート (Layer 2) |
| `shared/` | `Box/Projects/{{PROJECT_NAME}}/` | 成果物・参照 (Layer 3) |

## 主要ファイル一覧

### AI コンテキスト (`_ai-context/context/`)

| パス | 役割 | 読む優先度 |
|------|------|-----------|
| `_ai-context/context/project_summary.md` | プロジェクト全体像・背景・目標 | 最初に読む |
| `_ai-context/context/current_focus.md` | 現在の作業フォーカス・直近の状況 | 毎セッション確認 |
| `_ai-context/context/decision_log/` | 技術・設計判断の記録 (日付降順で最新3件) | 判断が必要なとき |
| `_ai-context/context/file_map.md` | このファイル (構造の地図) | 迷ったとき |
| `_ai-context/obsidian_notes/` | 詳細ノート・思考メモ (junction) | 深掘りが必要なとき |

### ローカル専用

| パス | 役割 |
|------|------|
| `CLAUDE.md` | Claude 向け指示 |
| `AGENTS.md` | 全AIエージェント向け指示 |
| `scripts/config.json` | プロジェクト設定 (tier, structure, etc.) |
| `development/source/` | ソースコード (Git管理) |

### BOX 同期 (`shared/` junction 経由)

| パス | 役割 |
|------|------|
| `shared/docs/` | ドキュメント (planning / design / testing / release) |
| `shared/reference/` | 参考資料 (vendor / standards / external) |
| `shared/records/` | 議事録・レポート・レビュー記録 |
| `shared/AGENTS.md` | 全AIエージェント向け指示 (master) |

### Git 管理

| パス | 役割 |
|------|------|
| `development/source/` | ソースコード本体 |

## 作業別ファイルナビ

- 現状把握から始めたい → `_ai-context/context/project_summary.md` → `_ai-context/context/current_focus.md`
- 過去の判断を確認したい → `_ai-context/context/decision_log/` (最新3件)
- 詳細な背景を調べたい → `_ai-context/obsidian_notes/`
- 成果物を確認したい → `shared/docs/` または `shared/reference/`
- コードを見たい → `development/source/`
