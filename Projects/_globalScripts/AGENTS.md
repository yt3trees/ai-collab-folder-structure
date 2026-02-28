# CLAUDE.md - _globalScripts

プロジェクト横断で使用するスクリプト群。

## Asana 同期スクリプト (sync_from_asana.py)

Asana タスクを案件別 Markdown ファイルとして Obsidian Vault に出力するスクリプト。
各案件フォルダの `asana-tasks.md` を通じて、AI が Asana タスクを直接参照できる。

### 設定ファイル構成

| ファイル | 場所 | 用途 |
|---------|------|------|
| `config.json` | `_globalScripts/` | グローバル設定 (token, user_gid, personal_project_gids) |
| `asana_config.json` | `Box/Projects/{案件}/` | 案件別設定 (asana_project_gids 配列) |

グローバル設定 (`config.json`):

```json
{
  "asana_token": "...",
  "workspace_gid": "...",
  "user_gid": "...",
  "personal_project_gids": ["..."],
  "output_file": ".../asana-tasks-view.md"
}
```

案件別設定 (`asana_config.json`, BOX 同期):

```json
{
  "asana_project_gids": ["gid1", "gid2"]
}
```

### 処理フロー

1. `_config/paths.json` から `boxProjectsRoot`, `obsidianVaultRoot` を取得
2. `boxProjectsRoot` 配下を走査し、`asana_config.json` を持つ案件を自動検出
3. 各案件の Asana プロジェクトから全タスクを取得
4. [担当] / [コラボ] / [他] のロールタグを付与
5. 個人プロジェクトのタスクは「案件」カスタムフィールドで各案件に振り分け

### 出力ファイル

| 出力先 | 内容 |
|-------|------|
| `{obsidianVaultRoot}/Projects/{案件}/asana-tasks.md` | 案件別タスク (Asana プロジェクト別グループ) |
| `{obsidianVaultRoot}/asana-tasks-personal.md` | 個人 / 未分類タスク |
| `{obsidianVaultRoot}/asana-tasks-view.md` | 全案件グローバルサマリー |

AI からのアクセスパス (ジャンクション経由):

```
{project}/_ai-context/obsidian_notes/asana-tasks.md
```

### 実行

```bash
cd Documents/Projects/_globalScripts
python sync_from_asana.py
```

### DON'Ts

- `asana-tasks.md`, `asana-tasks-personal.md`, `asana-tasks-view.md` は自動生成ファイル。直接編集しない (Memo area を除く)
- `config.json` に Asana トークンを含むため、Git にコミットしない
