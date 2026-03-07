# CLAUDE.md - _globalScripts

プロジェクト横断で使用するスクリプト群。

## Asana 同期スクリプト (sync_from_asana.py)

Asana タスクを案件別 Markdown ファイルとして Obsidian Vault に出力するスクリプト。
各案件フォルダの `asana-tasks.md` を通じて、AI が Asana タスクを直接参照できる。

### 設定ファイル構成

| ファイル | 場所 | 用途 |
|---------|------|------|
| `config.json` | `_globalScripts/` | グローバル設定 (token, user_gid, personal_project_gids) |
| `asana_config.json` | `Box/Projects/{案件}/` | 案件別設定 (asana_project_gids, anken_aliases) |

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
  "asana_project_gids": ["gid1", "gid2"],
  "anken_aliases": ["Asana上の案件名"]
}
```

- `asana_project_gids`: この案件に紐づく Asana プロジェクトの GID 配列
- `anken_aliases`: (任意) 個人プロジェクトの「案件」フィールド値がフォルダ名と異なる場合のエイリアス。フォルダ名と一致する場合は不要

### 処理フロー

1. `_config/paths.json` から `boxProjectsRoot`, `obsidianVaultRoot` を取得
2. `boxProjectsRoot` 配下（`_domains`や`_mini`等を含む）を走査し、すべての案件フォルダを自動検出
   - ※以前は `asana_config.json` が必須でしたが、現在はフォルダが存在するだけで検出対象になります。
3. 各案件の Asana プロジェクト（`asana_config.json`がある場合）および個人プロジェクトから全タスクを取得
   - 進行中のタスクに加え、**直近7日間** に完了したタスクも取得します（`Completed (recent)`用）。
4. [担当] / [コラボ] / [他] のロールタグを付与
5. 個人プロジェクト等のタスクは、Asanaの「案件」カスタムフィールドの値に基づいて各案件に自動振り分け
   - フォルダ名と「案件」フィールド値を突合します。
   - 突合の際、フォルダ名末尾の `[Domain]` や `[Mini]` といったサフィックスは無視（ストリップ）されます。
   - 例: フォルダ名が `GenAI [Domain]` でも、「案件」フィールドが `GenAI` なら正常にマッチします。
   - `asana_config.json` に `anken_aliases` が定義されていれば、そこに含まれる別名でもマッチングします。
6. タスクが1件以上ある場合、または既に設定/Markdownファイルが存在する場合のみ `asana-tasks.md` を出力

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