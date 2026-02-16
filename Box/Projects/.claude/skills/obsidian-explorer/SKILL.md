---
name: obsidian-explorer
description: "Search, read, save, and list notes in an Obsidian vault. Triggers on: 'search notes', 'find memos', 'save to Obsidian', 'show recent notes'."
---

## 概要

このスキルは、ユーザーがObsidianの保管庫(Vault)に保存した既存のメモを効率的に検索、参照、整理するためのものです。Windows環境でPowerShellスクリプト(.ps1)を使用し、bashシェルから `powershell.exe -File` 経由で呼び出します。全文検索(`-SearchType fulltext`)では、リポジトリ内の `bin` 配下に配置された ripgrep (`rg.exe`) を使用します。

## 前提条件

### Vaultパスの設定

`config.json` にObsidian保管庫のパスを設定してください(UTF-8 BOM付きで保存)。bashから環境変数を渡すと日本語パスが文字化けするため、設定ファイル方式を使用しています。`%USERPROFILE%` などのWindows環境変数も使用可能です。

```json
{
  "vaultPath": "%USERPROFILE%\\Documents\\Obsidian"
}
```

フォールバックとして環境変数 `OBSIDIAN_VAULT_PATH` も参照します。

### スクリプトの配置先

すべてのスクリプトは `~/.claude/skills/obsidian-explorer/script/` に配置されています。

- `script/Search-ObsidianNotes.ps1` - 検索スクリプト
- `script/Save-ObsidianNote.ps1` - メモ保存スクリプト
- `script/List-ObsidianNotes.ps1` - メモ一覧スクリプト
- `script/Get-ObsidianNote.ps1` - メモ閲覧(本文取得)スクリプト

### ripgrep の配置

全文検索で ripgrep を使用するため、以下のいずれかのパスに `rg.exe` を配置してください。

- 推奨: `~/.claude/skills/obsidian-explorer/bin/rg.exe`
- あるいは、`bin` 配下の任意のサブフォルダ（例: `bin/ripgrep-15.1.0-aarch64-pc-windows-msvc/rg.exe`）

`Search-ObsidianNotes.ps1` は、プロジェクトルートの `bin` 以下を再帰的に探索して最初に見つかった `rg.exe` を使用します。見つからない場合はエラー終了します。

---

## 検索 (Search-ObsidianNotes.ps1)

キーワードでObsidian保管庫内のメモを検索します。

### パラメータ

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Pattern | Yes | - | 検索キーワード(正規表現対応) |
| -SearchType | No | fulltext | 検索タイプ: fulltext / filename / heading / tag |
| -Folder | No | "" | 検索対象フォルダ(保管庫内の相対パス) |
| -Context | No | 1 | 前後の表示行数(fulltextのみ) |
| -MaxResults | No | 20 | 最大結果件数 |

### 使用例

```bash
# 全文検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "GRANDIT.*タイムアウト" -SearchType fulltext

# ファイル名検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "GRANDIT" -SearchType filename

# 見出し検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "パフォーマンス" -SearchType heading

# タグ検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "todo" -SearchType tag

# 特定フォルダ内を検索、前後3行表示
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "エラー" -Folder "Projects" -Context 3

# 結果を50件まで表示
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "TypeScript" -MaxResults 50
```

---

## メモ保存 (Save-ObsidianNote.ps1)

新しいメモを作成して保管庫に保存します。ファイル名には日付プレフィックス(yyyy-MM-dd)が自動付与されます。

### パラメータ

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Title | Yes | - | メモのタイトル |
| -Content | Yes | - | メモの内容(Markdown) |
| -Folder | No | "" | 保存先フォルダ(保管庫内の相対パス) |

### 使用例

```bash
# 保管庫のルートに保存
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "会議メモ" -Content "## 議題\n\n- 項目1\n- 項目2"

# 特定フォルダに保存
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "調査結果" -Content "内容" -Folder "Projects/Research"
```

---

## メモ一覧 (List-ObsidianNotes.ps1)

最近更新されたメモの一覧を表示します。

### パラメータ

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Days | No | 7 | 直近N日間のメモを表示 |
| -MaxResults | No | 20 | 最大表示件数 |

### 使用例

```bash
# 直近7日間のメモ一覧
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1"

# 直近30日間のメモを最大50件
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 30 -MaxResults 50
```

出力例:

```text
UPDATED:2026-02-16 12:34|PATH:Projects/XXX/メモ.md
UPDATED:2026-02-15 09:10|PATH:Inbox/メモ2.md
```

AIからは `UPDATED:` で始まる行を1件ずつパースすることで、相対パス(`PATH:`)を取得できます。

---

## メモ閲覧 (Get-ObsidianNote.ps1)

指定したメモファイルの本文を取得します。全文、先頭N行のプレビュー、見出し単位の3つのモードをサポートします。

### パラメータ

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Path | Yes | - | メモファイルのパス(保管庫内の相対パス、例: `Projects/XXX/メモ.md`) |
| -Mode | No | full | 取得モード: full / preview / section |
| -PreviewLines | No | 40 | Mode=preview 時の先頭取得行数 |
| -Heading | No | "" | Mode=section 時に取得したい見出し文字列(例: `調査結果` や `## 調査結果`) |

### 出力フォーマット

すべてのモードで、AIがパースしやすい固定フォーマットで出力されます。

```text
---OBSIDIAN-NOTE-BEGIN---
PATH: relative/path/to/note.md
MODE: full|preview|section
HEADING: 見出し名 (section モード時のみ)
---CONTENT-START---
(ここからメモ本文 or 抜粋)
...
---CONTENT-END---
---OBSIDIAN-NOTE-END---
```

AIは `---CONTENT-START---`〜`---CONTENT-END---` の範囲を本文として切り出せばよい設計です。

### 使用例

```bash
# メモの全文を取得
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode full

# 先頭60行だけプレビュー
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode preview -PreviewLines 60

# 見出し「調査結果」セクションを取得
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode section -Heading "調査結果"

# 見出しをフル指定することも可能
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode section -Heading "## 調査結果"
```

---

## 検索ワークフロー例

### ケース1: 「パフォーマンスについて調べたことを教えて」

```bash
# ステップ1: タグ検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance" -SearchType tag

# ステップ2: 見出し検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "パフォーマンス" -SearchType heading

# ステップ3: 全文検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "パフォーマンス改善|最適化" -SearchType fulltext -Context 2
```

### ケース2: 「最近のメモを確認したい」

```bash
# 最近7日間のメモ一覧を取得
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 7

# → 出力された PATH を元に、特定のメモを全文取得
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode full
```

### ケース3: 「この内容をメモしておいて」

```bash
# メモを保存
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "タイトル" -Content "保存したい内容" -Folder "Notes"

# → 後から内容を確認したい場合
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 1
# 最新メモの PATH を取得して、本文を閲覧
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Notes/2026-02-16-タイトル.md" -Mode preview -PreviewLines 40
```

### ケース4: 「特定見出しだけ読みたい」

```bash
# 見出しに「パフォーマンス」を含むメモを検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "パフォーマンス" -SearchType heading

# → 出力された PATH と見出し名を元に、そのセクションだけ取得
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/メモ.md" -Mode section -Heading "パフォーマンス"
```

---

## ガイドライン

- 検索しやすいメモを書く: 具体的な用語を使い、見出しやタグを活用する
- ファイル名を工夫する: 日付やカテゴリを含めると後から探しやすい
- フォルダ構造を整理する: Projects、Work、Learning など用途別に分類(2-3階層程度)
- 再利用する価値のある情報だけを保存し、一時的なメモは定期的に整理する

---

## トラブルシューティング

### 環境変数が認識されない

```bash
# bashから確認
powershell.exe -Command "echo \$env:OBSIDIAN_VAULT_PATH"
```

PowerShellプロファイル(`$PROFILE`)に `$env:OBSIDIAN_VAULT_PATH = "パス"` を追記してください。

### 日本語が文字化けする

スクリプト内でUTF-8エンコーディングを指定済みです。問題が続く場合はターミナルのエンコーディング設定を確認してください。

### 検索結果が多すぎる

- `-MaxResults` で件数を制限する
- `-Folder` で検索範囲を絞る
- `-SearchType filename` や `heading` で絞り込む
- 正規表現で複数キーワードを組み合わせる(例: `キーワード1.*キーワード2`)
