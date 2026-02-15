# ai-collab-folder-structure

![Workspace Architecture](_asset/ai-collab-folder-structure.drawio.svg)

AI(Claude Code)との協働を前提とした、プロジェクトフォルダ管理フレームワークです。

## 概要

複数プロジェクトを整理し、AIとのコンテキスト共有を最適化するための3層構造ワークスペースです。

- Layer 1 (Execution): ローカル作業領域(Git管理、揮発性の高い作業)
- Layer 2 (Knowledge): Obsidian Vault(思考・知見の蓄積、BOX同期)
- Layer 3 (Artifact): 成果物・参照資料(チーム共有、BOX同期)

## 3層レイヤー構造

| Layer | 役割 | 場所 | データの性質 |
|-------|------|------|-------------|
| Layer 1: Execution | 作業場 | Documents/Projects/{案件}/ (Local) | WIP、揮発性が高い |
| Layer 2: Knowledge | 思考・知識 | Box/Obsidian-Vault/ (BOX Sync) | 文脈、経緯、知見 |
| Layer 3: Artifact | 成果物・参照 | Box/Projects/{案件}/ (BOX Sync) | チーム共有ドキュメント |

## 特徴

### AIとの協働を設計に組み込み

- `.claude/context/` - AIが参照するコンテキストを集約
- `CLAUDE.md` - プロジェクト固有のAI指示書(実体はBOX側、ローカルにSymlink)
- ジャンクションによる知識ベース連携

### 2種類のプロジェクト Tier

| Tier | 配置先 | 用途 | 構成 |
|------|--------|------|------|
| full | `Projects/{案件}/` | メイン案件 | 全機能(_ai-workspace、構造化フォルダ) |
| light | `Projects/_support/{案件}/` | お手伝い系 | 軽量構成(最小限のフォルダ) |

### full tier の Structure オプション

full tier では、BOX側(Layer 3)のドキュメント構造を2種類から選択できます。

| Structure | 説明 |
|-----------|------|
| new (デフォルト) | 用途別分類(docs/reference/records) |
| legacy | フェーズ番号ベース(01_planning 〜 10_reference) |

### 2PC間の同期戦略

- BOX同期: Obsidian Vault、shared/ 経由の成果物
- Git同期: ソースコード(development/source/)
- ローカル独立: .claude/、_ai-workspace/

## ワークスペース全体の構成

```
Documents/Projects/
├── _config/
│   └── paths.json              # ワークスペース共通パス定義
├── _projectTemplate/           # プロジェクトテンプレート・管理スクリプト
│   ├── scripts/
│   │   ├── project_launcher.ps1    # GUIランチャー
│   │   ├── setup_project.ps1       # プロジェクト初期セットアップ
│   │   ├── check_project.ps1       # 健全性チェック
│   │   ├── archive_project.ps1     # 完了プロジェクトのアーカイブ
│   │   ├── config.template.json    # 設定ファイルテンプレート
│   │   └── _exec_project_launcher.cmd  # GUIランチャー起動用バッチ
│   ├── CLAUDE.md               # 新規プロジェクト用CLAUDE.mdテンプレート
│   └── README.md               # テンプレート詳細ドキュメント
├── _globalScripts/             # プロジェクト横断スクリプト
│   ├── sync_from_asana.py      # Asana → Markdown同期
│   └── config.json.example     # Asana同期の設定例
├── _archive/                   # アーカイブ済みプロジェクト
│   └── _support/               # アーカイブ済み light tier プロジェクト
├── _support/                   # light tier プロジェクト群
├── _ai-workspace/              # ワークスペース全体のAI分析・実験用
├── CLAUDE.md                   # ワークスペース全体のAI指示書
├── README.md                   # 本ファイル
├── workspace-architecture.md   # 詳細設計ドキュメント
└── {ProjectName}/              # 各プロジェクト (full tier)
```

## プロジェクトフォルダ構成

### full tier

```
Documents/Projects/{ProjectName}/
├── .claude/                    # AI専用領域 [Local]
│   └── context/
│       └── obsidian_notes/     # Junction → Box/Obsidian-Vault/Projects/{ProjectName}
├── _ai-workspace/              # AI分析・実験用 [Local]
├── development/                # 開発関連 [Local - Git管理]
│   ├── source/                 # ソースコード
│   ├── config/                 # 設定ファイル
│   └── scripts/                # 開発スクリプト
├── scripts/                    # プロジェクト管理スクリプト [Local]
│   ├── config.json             # プロジェクト設定
│   └── config/                 # 追加設定ファイル
├── shared/                     # Junction → Box/Projects/{ProjectName}
└── CLAUDE.md                   # Symlink → Box/Projects/{ProjectName}/CLAUDE.md

Box/Projects/{ProjectName}/         (new 構造)
├── CLAUDE.md                   # AI指示書 (実体)
├── docs/                       # 作成・編集ドキュメント
│   ├── planning/               # 企画・要件定義・提案書
│   ├── design/                 # 設計書
│   ├── testing/                # テスト計画・ケース・結果
│   └── release/                # リリース・移行手順
├── reference/                  # 参考資料 (読むだけ・保存用)
│   ├── vendor/                 # ベンダー提供資料
│   ├── standards/              # 社内規約・標準
│   └── external/               # その他外部資料
├── records/                    # 記録・履歴 (証跡)
│   ├── minutes/                # 議事録
│   ├── reports/                # 進捗報告
│   └── reviews/                # レビュー記録
└── _work/                      # 日付ベースの作業フォルダ
```

### light tier

```
Documents/Projects/_support/{ProjectName}/
├── .claude/                    # AI専用領域 [Local]
│   └── context/
│       └── obsidian_notes/     # Junction → Box/Obsidian-Vault/Projects/_support/{ProjectName}
├── development/                # 開発関連 [Local]
│   ├── source/                 # ソースコード (Git管理)
│   ├── config/                 # 設定ファイル
│   └── scripts/                # 開発スクリプト
├── scripts/                    # プロジェクト管理スクリプト [Local]
│   └── config.json             # プロジェクト設定 (tier 情報を含む)
├── shared/                     # Junction → Box/Projects/_support/{ProjectName}
└── CLAUDE.md                   # Symlink → Box/Projects/_support/{ProjectName}/CLAUDE.md

Box/Projects/_support/{ProjectName}/
├── CLAUDE.md                   # AI指示書 (実体)
├── docs/                       # ドキュメント (flat - サブフォルダなし)
└── _work/                      # 作業フォルダ
```

## リンク構成

| 種類 | ローカル側 | リンク先 (BOX側) | 管理者権限 |
|------|-----------|-----------------|-----------|
| Junction | shared/ | Box/Projects/{ProjectName}/ | 不要 |
| Junction | .claude/context/obsidian_notes/ | Box/Obsidian-Vault/Projects/{ProjectName}/ | 不要 |
| Symlink | CLAUDE.md | Box/Projects/{ProjectName}/CLAUDE.md | 必要 (開発者モード) |

## クイックスタート

### 1. 前提条件

`Documents/Projects/_config/paths.json` を作成:

```json
{
  "localProjectsRoot": "Documents\\Projects",
  "boxProjectsRoot": "Box\\Projects",
  "obsidianVaultRoot": "Box\\Obsidian-Vault"
}
```

各値は `%USERPROFILE%` からの相対パスです。

CLAUDE.md のシンボリックリンク作成には、開発者モードの有効化が必要です:
- Windows設定 → システム → 開発者向け → 開発者モード ON (推奨)
- または、管理者権限でスクリプトを実行

### 2. GUIランチャーで操作 (推奨)

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\project_launcher.ps1"
```

または `_projectTemplate\scripts\_exec_project_launcher.cmd` をダブルクリックでも起動できます。

機能:
- Setup タブ: プロジェクト名、Structure、Tier を選択してセットアップ
- Check タブ: 既存プロジェクトの健全性チェック
- Archive タブ: DryRun プレビュー付きでアーカイブ実行
- 出力エリアにスクリプトの実行結果をリアルタイム表示

### 3. コマンドラインで操作

```powershell
# メイン案件 (full tier, new 構造 - デフォルト)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject"

# メイン案件 (full tier, legacy 構造)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject" -Structure legacy

# お手伝い系 (light tier)
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "SupportProject" -Tier light
```

### 4. 健全性チェック

```powershell
# メイン案件
.\_projectTemplate\scripts\check_project.ps1 -ProjectName "NewProject"

# お手伝い系
.\_projectTemplate\scripts\check_project.ps1 -ProjectName "SupportProject" -Support
```

### 5. プロジェクトのアーカイブ

```powershell
# DryRun で確認 (実際には何も変更しない)
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "MyProject" -DryRun

# 実行
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "MyProject"

# お手伝い系
.\_projectTemplate\scripts\archive_project.ps1 -ProjectName "SupportProject" -Support -DryRun
```

アーカイブは3層すべてを `_archive/` に移動します。light tier は `_archive/_support/` 配下に移動されます。

### 6. PC-B でのセットアップ

BOX同期完了後、同じスクリプトを実行するだけでジャンクションとシンボリックリンクが作成されます:

```powershell
.\_projectTemplate\scripts\setup_project.ps1 -ProjectName "NewProject"
```

- `_config/paths.json` は各PCで個別に作成が必要(BOX非同期)
- CLAUDE.md はBOX同期済みなのでシンボリックリンクのみ作成される

## スクリプト一覧

### _projectTemplate/scripts/

| スクリプト | 用途 |
|-----------|------|
| `project_launcher.ps1` | GUI ランチャー(全スクリプトを統合) |
| `setup_project.ps1` | プロジェクト初期セットアップ |
| `check_project.ps1` | 健全性チェック |
| `archive_project.ps1` | 完了プロジェクトのアーカイブ |
| `config.template.json` | 設定ファイルテンプレート |
| `_exec_project_launcher.cmd` | GUIランチャー起動用バッチファイル |

### _globalScripts/

| スクリプト | 用途 |
|-----------|------|
| `sync_from_asana.py` | Asanaタスク → Markdown同期 |
| `config.json.example` | Asana同期の設定ファイル例 |

## ドキュメント

- [workspace-architecture.md](workspace-architecture.md) - 詳細設計ドキュメント
- [_projectTemplate/README.md](_projectTemplate/README.md) - テンプレート詳細ドキュメント
- [CLAUDE.md](CLAUDE.md) - ワークスペース全体のAI指示書

## 制約事項

- Windows専用(ジャンクション・PowerShellスクリプト)
- BOX Driveが必要(Layer 2/3の同期)
- 同一ボリューム内でのみジャンクションが有効
- .ps1 スクリプトは Shift_JIS (cp932) で記述、出力は UTF-8
- CLAUDE.md の Symlink 作成には開発者モードまたは管理者権限が必要
- Obsidian Vault は2台のPCで同時に開かない(データ上書き防止)

## License

MIT License
