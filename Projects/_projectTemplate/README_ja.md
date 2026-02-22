# Project Template

新規プロジェクトを作成するための標準テンプレートです。
3層レイヤー構造(Execution/Knowledge/Artifact)に基づいたフォルダ構成と、自動化スクリプトを提供します。

## 概要

このテンプレートは以下を含みます:

- ローカル専用フォルダの作成 (_ai-workspace, development)
- BOX共有フォルダの作成 (自動同期)
- ジャンクションの自動設定 (shared/, obsidian_notes/)
- AGENTS.md, CLAUDE.md のコピー作成 (BOX側がマスター)
- _ai-context フォルダの作成と Obsidian Junction の設定
- Obsidian Vault プロジェクトフォルダと Indexファイルの自動作成
- 健全性チェック機能

## 前提条件

### 1. paths.json の作成

すべてのスクリプトは `_config/paths.json` からパス情報を読み込みます。
初回のみ、以下のファイルを作成してください:

ファイル: `Documents/Projects/_config/paths.json`

```json
{
  "localProjectsRoot": "%USERPROFILE%\\Documents\\Projects",
  "boxProjectsRoot": "%USERPROFILE%\\Box\\Projects",
  "obsidianVaultRoot": "%USERPROFILE%\\Box\\Obsidian-Vault"
}
```

各値はフルパスで記述します。`%USERPROFILE%` などの環境変数は自動的に展開されます。
PC-B でも同じ構成であればそのまま使えます。
BOXの同期先が異なるPCでは、該当パスを変更してください。

### 2. 開発者モードの有効化

AGENTS.md / CLAUDE.md のシンボリックリンク作成には、以下のいずれかが必要です:
- 管理者権限で PowerShell を実行する
- または、Windows の開発者モードを有効にする (設定 > 更新とセキュリティ > 開発者向け)

Obsidian Junction について:
- デフォルトで `_ai-context/obsidian_notes/` から BOX へのジャンクションを作成します。

## 使用方法

### 1. paths.json の確認

`Documents/Projects/_config/paths.json` が存在するか確認します。
なければ「前提条件」セクションを参照して作成してください。

### 2. GUIで操作する (推奨)

GUIランチャーを使うと、Setup / Check / Archive の操作をグラフィカルに実行できます。

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\project_launcher.ps1"
```

または、`_projectTemplate/scripts/` フォルダ内の `project_launcher.ps1` を右クリック → 「PowerShell で実行」でも起動できます。

機能:
- Setup タブ: プロジェクト名と Tier を選択してセットアップ
- Check タブ: 既存プロジェクトをドロップダウンから選んで健全性チェック
- Archive タブ: DryRun プレビュー付きでアーカイブ実行
- 出力エリアにスクリプトの実行結果をリアルタイム表示

### 3. コマンドラインで操作する

PowerShellを開き、以下のコマンドを実行します:

```powershell
# テンプレートディレクトリに移動
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# メイン案件 (full tier) のセットアップ
.\setup_project.ps1 -ProjectName "MyNewProject"

# お手伝い系プロジェクト (mini tier) のセットアップ
.\setup_project.ps1 -ProjectName "SupportProject" -Tier mini
```

パラメータ:
- `-ProjectName` (必須): プロジェクト名
- `-Tier` (オプション): `full` (デフォルト、メイン案件) または `mini` (お手伝い系)

スクリプトが実行する内容 (full tier):
1. ローカルフォルダの作成 (_ai-context, _ai-workspace, development)
2. BOX共有フォルダの作成 (docs, reference, records, _work)
3. Obsidian Vault プロジェクトフォルダの作成 (daily, meetings, specs, notes, weekly) と Indexファイルの作成
4. ジャンクション作成 (shared/, obsidian_notes/)
5. AGENTS.md/CLAUDE.md コピー作成 (BOX側 → ローカル)

スクリプトが実行する内容 (mini tier):
1. ローカルフォルダの作成 (_ai-context, development) - _ai-workspace なし
2. BOX共有フォルダの作成 (docs, _work) - 軽量構成
3. Obsidian Vault プロジェクトフォルダの作成 (notes のみ) と Indexファイルの作成
4. ジャンクション作成 (shared/, obsidian_notes/)
5. AGENTS.md/CLAUDE.md コピー作成 (BOX側 → ローカル)

### 4. AGENTS.md の自動作成

`AGENTS.md` (AI指示書) がBOX側に存在しない場合、セットアップスクリプトは自動的にデフォルトファイルを作成します。
その後、BOX側のファイルをローカルへコピーして `AGENTS.md` と `CLAUDE.md` を作成します。

> 注意: これらは独立したファイルコピーです。シンボリックリンクではありません。
> BOX側の `AGENTS.md` を更新した場合は、手動でローカルにコピーするか、再度 `setup_project.ps1` を実行して上書きしてください。

作成後、内容は必要に応じて編集してください:

```powershell
notepad "$env:USERPROFILE\Box\Projects\MyNewProject\AGENTS.md"
```

### 5. セットアップの確認

```powershell
# メイン案件の確認
.\check_project.ps1 -ProjectName "MyNewProject"

# お手伝い系プロジェクト (mini tier) の確認
.\check_project.ps1 -ProjectName "SupportProject" -Mini
```

このスクリプトは以下をチェックします:
- Junction: `shared/` と `_ai-context/obsidian_notes/` が正しくリンクされているか
- Files: `AGENTS.md` と `CLAUDE.md` (BOXからのコピー) が存在するか
- Shortcuts: `.lnk` ファイルが切れていないか

### 6. 完了プロジェクトのアーカイブ

プロジェクトが完了したら、以下のコマンドで3層すべてを `_archive/` に移動できます:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# メイン案件のアーカイブ
# まず DryRun で確認 (実際には何も変更しない)
.\archive_project.ps1 -ProjectName "MyProject" -DryRun

# 問題なければ実行
.\archive_project.ps1 -ProjectName "MyProject"

# お手伝い系プロジェクト (mini tier) のアーカイブ
.\archive_project.ps1 -ProjectName "SupportProject" -Mini -DryRun
.\archive_project.ps1 -ProjectName "SupportProject" -Mini
```

パラメータ:
- `-ProjectName` (必須): アーカイブするプロジェクト名
- `-Mini` (オプション): mini tier プロジェクト (_mini/ 配下) の場合に指定
- `-DryRun` (オプション): 変更内容を表示するだけで実行しない
- `-Force` (オプション): 確認プロンプトをスキップ

スクリプトが実行する内容:
1. ジャンクション (shared/, obsidian_notes/) と AIシンボリックリンク (AGENTS.md, CLAUDE.md) を安全に解除
2. Layer 3 (BOX成果物) を `Box/Projects/_archive/{ProjectName}/` に移動
   - お手伝い系の場合: `Box/Projects/_archive/_mini/{ProjectName}/`
3. Layer 2 (Obsidianナレッジ) を `Box/Obsidian-Vault/Projects/_archive/{ProjectName}/` に移動
   - お手伝い系の場合: `Box/Obsidian-Vault/Projects/_archive/_mini/{ProjectName}/`
4. Layer 1 (ローカル) を `Documents/Projects/_archive/{ProjectName}/` に移動
   - お手伝い系の場合: `Documents/Projects/_archive/_mini/{ProjectName}/`
5. `00_Projects-Index.md` に参照がある場合は手動更新を案内

### 7. Tier の変換

既存プロジェクトの Tier を変換できます:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# Mini → Full に変換 (DryRunで確認)
.\convert_tier.ps1 -ProjectName "SupportProject" -To full -DryRun
.\convert_tier.ps1 -ProjectName "SupportProject" -To full

# Full → Mini に変換
.\convert_tier.ps1 -ProjectName "MyProject" -To mini -DryRun
.\convert_tier.ps1 -ProjectName "MyProject" -To mini
```

パラメータ:
- `-ProjectName` (必須): 変換するプロジェクト名
- `-To` (必須): 変換先 Tier (`full` or `mini`)
- `-DryRun` (オプション): 変更内容を表示するだけで実行しない

スクリプトが実行する内容:
1. 既存のジャンクションとAI指示書コピーを解除
2. 3層すべてのフォルダを変換先の場所に移動
3. 変換先 Tier に必要な追加フォルダを作成
4. ジャンクションとAI指示書コピーを再作成

> 注意: Full → Mini 変換時、Full 固有のフォルダ (_ai-workspace/, reference/, records/ 等) のファイルは削除されず保持されます。

### 8. PC-B でのセットアップ

PC-B ではBOX同期完了後、同じスクリプトを実行するだけで環境が構築されます:

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# paths.json は各PCで個別に作成 (BOXパスが異なる場合のみ変更)
# ジャンクションとシンボリックリンクを作成
.\setup_project.ps1 -ProjectName "MyNewProject"
```

- `_config/paths.json` が各PCに必要 (BOX非同期のため)
- AGENTS.md はBOX同期済みなので、シンボリックリンクのみ作成される
- ジャンクションもローカルのみなので、各PCで作成が必要

## プロジェクト Tier

プロジェクトの規模と関与度に応じて、2種類の Tier を選択できます。

| Tier | 配置先 | 用途 | 構成 |
|------|--------|------|------|
| full | `Projects/{案件}/` | メイン案件 (フル機能) | 全フォルダ、全機能 |
| mini | `Projects/_mini/{案件}/` | お手伝い系 (軽量構成) | 最小限のフォルダ、シンプル |

### Tier 別フォルダ構成の違い

| 要素 | full | mini |
|------|------|-------|
| Layer 1 (_ai-context/) | あり | あり |
| Layer 1 (_ai-workspace/) | あり | なし |
| Layer 2 (Obsidian) | daily, meetings, specs, notes, weekly | notes のみ |
| Layer 3 (BOX docs/) | planning, design, testing, release | flat (サブフォルダなし) |
| Layer 3 (reference/) | あり (vendor, standards, external) | なし |
| Layer 3 (records/) | あり (minutes, reports, reviews) | なし |
| Layer 3 (_work/) | あり | あり |

## フォルダ構造

### full 構造

用途別に分類された構造です:

```
Box/Projects/{ProjectName}/
├── AGENTS.md            # プロジェクト固有AI指示書 (実体 - Master)
├── docs/                # 作成・編集するドキュメント
│   ├── planning/        # 企画・要件定義・提案書
│   ├── design/          # 設計書 (基本/詳細/データモデル/UI)
│   ├── testing/         # テスト計画・ケース・結果
│   └── release/         # リリース・移行手順・環境構築
│
├── reference/           # 参考資料 (読むだけ・保存用)
│   ├── vendor/          # ベンダー提供資料・仕様書
│   ├── standards/       # 社内規約・標準・ガイドライン
│   └── external/        # その他外部資料・調査結果
│
├── records/             # 記録・履歴 (証跡として残す)
│   ├── minutes/         # 議事録
│   ├── reports/         # 進捗報告・ステークホルダー向け
│   └── reviews/         # レビュー記録・承認履歴
│
└── _work/            # 日付ベースの作業フォルダ
    └── 2026/
        └── 01/
            └── 25_XXXの件対応/
```

### mini 構造 (お手伝い系)

軽量構成。`_mini/` 配下に配置されます。

```
Documents/Projects/_mini/{ProjectName}/
├── _ai-context/                # Common Context [Local]
│   └── obsidian_notes/         # Junction → Box/Obsidian-Vault/Projects/_mini/{ProjectName}
├── development/                # 開発関連 [Local]
│   ├── source/                 # ソースコード (Git管理)
│   └── config/                 # 設定ファイル
│
├── shared/                     # Junction → Box/Projects/_mini/{ProjectName}
├── AGENTS.md                   # Copy from shared/AGENTS.md
└── CLAUDE.md                   # Copy from shared/AGENTS.md

Box/Projects/_mini/{ProjectName}/
├── AGENTS.md                   # プロジェクト固有AI指示書 (実体 - Master)
├── docs/                       # ドキュメント (flat - サブフォルダなし)
└── _work/                      # 作業フォルダ

Box/Obsidian-Vault/Projects/_mini/{ProjectName}/
├── notes/                      # ノート
└── 00_{ProjectName}-Index.md  # プロジェクトインデックス
```

## ローカルフォルダ構造 (full tier)

```
Documents/Projects/{ProjectName}/
├── _ai-context/                # Shared AI Context (Read from here!)
│   └── obsidian_notes/         # Junction → Box/Obsidian-Vault/Projects/{ProjectName}
│
├── _ai-workspace/              # AI分析・実験用 [Local]
│
├── development/                # 開発関連 [Local]
│   ├── source/                 # ソースコード (Git管理)
│   ├── config/                 # 設定ファイル
│   └── scripts/                # 開発スクリプト
│
├── shared/                     # Junction → Box/Projects/{ProjectName}
├── AGENTS.md                   # Copy from shared/AGENTS.md
└── CLAUDE.md                   # Copy from shared/AGENTS.md
```

## ワークスペース設定ファイル

```
Documents/Projects/
├── _config/
│   └── paths.json              # ワークスペース共通パス定義
├── _projectTemplate/           # このテンプレート
├── _globalScripts/             # プロジェクト横断スクリプト
├── ProjectA/                   # プロジェクトA
└── ProjectB/                   # プロジェクトB
```

## 含まれるスクリプト

| スクリプト | 用途 | 実行場所 |
|-----------|------|---------|
| `project_launcher.ps1` | GUI ランチャー (全スクリプトを統合) | `_projectTemplate/scripts/` |
| `setup_project.ps1` | プロジェクトの初期セットアップ | `_projectTemplate/scripts/` |
| `check_project.ps1` | 健全性チェック | `_projectTemplate/scripts/` |
| `archive_project.ps1` | 完了プロジェクトのアーカイブ | `_projectTemplate/scripts/` |
| `convert_tier.ps1` | Tier 変換 (mini <-> full) | `_projectTemplate/scripts/` |
| `config.template.json` | 設定ファイルのテンプレート | コピーして使用 |

## 3層レイヤー構造との対応

| Layer | 役割 | 場所 | データの性質 |
|------|------|------|-------------|
| Layer 1: Execution | 作業場 | Documents/Projects/{ProjectName}/ (Local) | WIP、揮発性が高い |
| Layer 2: Knowledge | 思考・知識 | Box/Obsidian-Vault/ (BOX Sync) | 文脈、経緯、知見 |
| Layer 3: Artifact | 成果物・参照 | Box/Projects/{ProjectName}/ (BOX Sync) | バックアップ・PC間同期ドキュメント |

## リンク構成まとめ

| 種類 | ローカル側 | → | BOX側 (実体) | BOX同期 | 管理者権限 |
|------|-----------|---|-------------|---------|-----------|
| Junction | shared/ | → | Box/Projects/{ProjectName}/ | - | 不要 |
| Junction | _ai-context/obsidian_notes/ | → | Box/Obsidian-Vault/Projects/{ProjectName}/ | - | 不要 |
| Copy | AGENTS.md | ← | Box/Projects/{ProjectName}/AGENTS.md | 実体が同期 (Master) | 不要 |
| Copy | CLAUDE.md | ← | Box/Projects/{ProjectName}/AGENTS.md | Claude用コピー | 不要 |

## Obsidian Vault との連携

セットアップ時に以下が自動作成されます:

- `shared/` → `Box/Projects/{ProjectName}/` (成果物)
- `_ai-context/obsidian_notes/` → `Box/Obsidian-Vault/Projects/{ProjectName}/` (知識ベース)
- Obsidian Vault 内のプロジェクトフォルダ (daily, meetings, specs, notes, weekly)
- `00_{ProjectName}-Index.md`

Obsidianで以下のファイルを作成してください:

- `Projects/{ProjectName}/00_{ProjectName}-Index.md` (案件ホームページ)
- `Projects/{ProjectName}/daily/YYYY-MM-DD.md` (デイリーノート)

## 注意事項

- このテンプレート自体を変更しないでください
- 新規プロジェクト作成時は必ずこのテンプレートからスクリプトを実行してください
- `shared/` フォルダはBoxへのジャンクションです。直接中身をコミットしないでください
- Obsidian Vault は2台のPCで同時に開かないでください (データ上書き防止)
- Gitリポジトリは `development/source/` に配置し、`.git/` はBOX同期しないでください
- `_config/paths.json` はBOX同期されません。各PCで個別に作成が必要です

## トラブルシューティング

### paths.json が見つからない

スクリプト実行時に "Paths config not found" エラーが出る場合:

```powershell
# _config フォルダが存在するか確認
Test-Path "$env:USERPROFILE\Documents\Projects\_config\paths.json"

# なければ作成 (「前提条件」セクション参照)
```

### ジャンクションが作成されない

Box同期が完了しているか確認してください:
```powershell
Test-Path "$env:USERPROFILE\Box\Projects\{ProjectName}"
```

### AI指示書 (AGENTS.md / CLAUDE.md) が更新されない

- 原因: シンボリックリンクではなくファイルコピーを使用しているため、BOX側を変更してもローカルには反映されません。
- 対策: ローカルファイルを直接編集するか、BOX側を編集した後に手動でコピーしてください。


### 手動でのシンボリックリンク作成 (参考)

```powershell
# AGENTS.md (Local -> Box)
New-Item -ItemType SymbolicLink -Path "Documents\Projects\{ProjectName}\AGENTS.md" -Target "Box\Projects\{ProjectName}\AGENTS.md"
# CLAUDE.md (Local -> Local AGENTS.md)
cd Documents\Projects\{ProjectName}
New-Item -ItemType SymbolicLink -Path "CLAUDE.md" -Target "AGENTS.md"
```

### 設定ファイルが見つからない

`scripts/config.json` は `check_project.ps1` が参照する設定ファイルです。手動で作成するか、`config.template.json` を参考にしてください。

### Obsidian連携が動作しない

Obsidian Vault のパスが正しいか確認してください:
```powershell
Test-Path "$env:USERPROFILE\Box\Obsidian-Vault\Projects\{ProjectName}"
```

## 関連ドキュメント

- `AGENTS.md` - このテンプレートのAGENTS.mdテンプレート
- `_config/paths.json` - ワークスペース共通パス定義
- `workspace-architecture.md` - 詳細な設計ドキュメント
- `_globalScripts/sync_from_asana.py` - Asana連携スクリプト
