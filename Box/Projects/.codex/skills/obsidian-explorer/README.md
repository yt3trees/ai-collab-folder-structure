# obsidian-explorer

Claude Codeから Obsidian保管庫(Vault)のメモを検索・保存・一覧表示するスキル。

Windows環境でbashシェルから `powershell.exe -File` 経由でPowerShellスクリプトを呼び出す形式。

## セットアップ

### 1. config.json の設定

`config.json` にObsidian保管庫のパスを設定する。UTF-8 BOM付きで保存すること。

```json
{
  "vaultPath": "C:\\Users\\YourUser\\Documents\\Obsidian"
}
```

フォールバックとして環境変数 `OBSIDIAN_VAULT_PATH` も参照するが、bash経由だと日本語パスが文字化けするため config.json を推奨。

### 2. .ps1ファイルのエンコーディング

すべての .ps1 ファイルはUTF-8 BOM付きで保存する必要がある(PowerShell 5.1が日本語を正しくパースするため)。

BOM付きで再保存する方法:

```powershell
$path = "対象ファイル.ps1"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
```

## ファイル構成

```
~/.claude/skills/obsidian-explorer/
  skill.md                  - スキル定義(Claude Codeが参照)
  config.json               - Vaultパス設定
  Search-ObsidianNotes.ps1  - 検索スクリプト
  Save-ObsidianNote.ps1     - メモ保存スクリプト
  List-ObsidianNotes.ps1    - メモ一覧スクリプト
  README.md                 - このファイル
```

## 使い方

### 全文検索

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "キーワード" -SearchType fulltext
```

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Pattern | Yes | - | 検索キーワード(正規表現対応) |
| -SearchType | No | fulltext | fulltext / filename / heading / tag |
| -Folder | No | "" | 検索対象フォルダ(Vault内の相対パス) |
| -Context | No | 1 | 前後の表示行数(fulltextのみ) |
| -MaxResults | No | 20 | 最大結果件数 |

検索タイプの説明:

- fulltext: ファイル内容を正規表現で検索
- filename: ファイル名にキーワードを含むメモを検索
- heading: Markdown見出し(# ~ ######)にキーワードを含むメモを検索
- tag: Obsidianタグ(#キーワード)を検索

### メモ保存

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Save-ObsidianNote.ps1" -Title "タイトル" -Content "内容"
```

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Title | Yes | - | メモのタイトル |
| -Content | Yes | - | メモの内容(Markdown) |
| -Folder | No | "" | 保存先フォルダ(Vault内の相対パス) |

ファイル名は `yyyy-MM-dd-タイトル.md` の形式で自動生成される。

### メモ一覧

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/List-ObsidianNotes.ps1" -Days 7
```

| パラメータ | 必須 | 既定値 | 説明 |
|-----------|------|--------|------|
| -Days | No | 7 | 直近N日間のメモを表示 |
| -MaxResults | No | 20 | 最大表示件数 |

## 実行例

```bash
# GRANDITに関するメモをファイル名で検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "GRANDIT" -SearchType filename

# 特定フォルダ内で全文検索、前後3行表示
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "エラー" -Folder "_GRANDIT" -Context 3

# 見出しに「トラブル」を含むメモを検索
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "トラブル" -SearchType heading

# 直近30日のメモを50件まで表示
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/List-ObsidianNotes.ps1" -Days 30 -MaxResults 50

# メモを保存(Projectsフォルダに)
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Save-ObsidianNote.ps1" -Title "調査メモ" -Content "調査内容" -Folder "Projects"
```

## パフォーマンスについて

保管庫がBox等のクラウド同期フォルダにある場合、全文検索は遅くなる可能性がある。
対策として `[System.IO.File]::ReadAllLines` による一括読み込みでI/O回数を最小化している。

さらに高速化したい場合:
- `-Folder` で検索範囲を限定する
- `-MaxResults` で結果件数を制限する
- `-SearchType filename` で内容を読まずにファイル名だけで絞り込む

## トラブルシューティング

### スクリプト実行時に文字化けする

.ps1ファイルがUTF-8 BOM付きで保存されているか確認する。

### Vaultパスが見つからないエラー

config.json のパスが正しいか確認する。パス区切りは `\\` でエスケープが必要。

### 検索結果が0件になる

- 正規表現の特殊文字(`.*+?[](){}`)がエスケープされていない可能性がある
- 単純な文字列検索なら `[regex]::Escape("検索文字列")` 相当のパターンを使う
