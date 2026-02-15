# プロジェクト資料管理改善プラン

## Context (背景と目的)

現在、Projectの資料管理において以下の課題が存在している:

- ファイル共有にBOX、タスク管理にAsanaを使用 (会社標準)
- 個人メモはObsidianで複数案件をまとめて管理
- 2台のPC間で同期が必要
- ソースコード (development/source) はBOX同期したくない (容量問題)
- その他のファイルは2PC間でBOX同期したい
- タスク管理はAsanaをベースにしたいが、AIとの協働ではテキストベース管理も必要

この改善プランでは、BOX、Asana、Obsidian、Claude AIを統合した効率的な資料管理システムを構築し、2PC間のシームレスな作業環境を実現する。

## 選択した方針

1. Obsidian配置: 外部参照パターン (VaultとProjectAを分離)
2. Asana統合: 軽量統合 (週次手動同期)
3. ソースコード管理: Git管理 (ローカル+リモートリポジトリ)
4. Vault同期: Obsidian VaultをBOXフォルダ内に配置して2PC間同期

---

## 1. コンセプト: 3層レイヤー構造による責務分離

物理的な配置(BOX/Local)だけでなく、「情報の責務」に基づく3層構造を採用し、堅牢性と運用効率を両立させます。

| レイヤー | 役割 | ツール/保管場所 | データの性質 | Source of Truth |
| :--- | :--- | :--- | :--- | :--- |
| Layer 1: Execution | 実行・作業 | Documents/Projects/ProjectA (Local)<br>Git (Source)<br>Asana (Task) | Work in Progress (WIP)<br>揮発性が高い、速度優先 | Git / Asana / Local |
| Layer 2: Knowledge | 思考・知識 | Obsidian Vault (BOX) | Linked Knowledge<br>文脈、経緯、知見、ドラフト | Vault (Markdown) |
| Layer 3: Artifact | 成果物・参照 | Box/Projects/ProjectA (BOX Sync) | Shared Docs (+ 手動Symlink)<br>チーム共有ドキュメント + 公式資料参照 | Official / Shared |

### ジャンクション方針: 2本構成

Layer 1のローカルフォルダ内に2本のジャンクションを作成し、Layer 2 (Knowledge) と Layer 3 (Artifact) を統合する。

1. `shared/` → Box/Projects/ProjectA (Layer 3: 成果物・参照)
3. `_ai-context/obsidian_notes/` → Box/Obsidian-Vault/Projects/ProjectA (Layer 2: 知識ベース - AI参照用)

ローカル専用領域とBOX同期領域が `shared/` の内外で明確に分かれる:
- `shared/` の外 = ローカル専用 (BOX非同期) ※ただし `_ai-context` はAI設定の一部として管理
- `shared/` の中 = BOX同期 (他PCや共有先に影響)

### Multi-CLI Support

複数のAI CLIツール (Claude Code, Codex CLI, Gemini CLI) に対応するため、以下の構成をとる:

1. **Instructions**: `AGENTS.md` をマスターとしてBOX同期 (`shared/`直下)。ローカルには `CLAUDE.md` 等の必要なエイリアスを Symlink で作成。
2. **Context**: `_ai-context/` フォルダに共通の参照情報 (Obsidianジャンクション等) を配置。各CLIにはこのフォルダを参照させる。

---

## 2. フォルダ構成詳細

### 全体マップ

```
%USERPROFILE%\
├── Documents\
│   └── Projects\
│       ├── _globalScripts\                (プロジェクト横断共通スクリプト) [Local]
│       │   └── sync_from_asana.py         (Asana同期スクリプト)
│       │
│       └── ProjectA\                      [Layer 1: Execution]
│           ├── _ai-context\               (Common AI Context) [Local]
│           │   └── obsidian_notes\        ← Junction → Box/Obsidian-Vault/Projects/ProjectA
│           ├── _temp\                     (一時ファイル・作業中) [Local]
│           ├── development\               (Source Code - Git Managed) [Local]
│           │   ├── source\                (.git 含む、BOX非同期)
│           │   ├── config\
│           │   └── scripts\
│           ├── shared\                    ← Junction 1本 → Box/Projects/ProjectA
│           │   ├── AGENTS.md              (Master AI Instruction) [BOX Sync]
│           │   └── ...
│           ├── AGENTS.md                  (Master AI Instruction - Copy from shared)
│           └── CLAUDE.md                  (Claude CLI Alias - Copy from shared)
│
└── Box\
    ├── Obsidian-Vault\                    [Layer 2: Knowledge - BOX Sync]
    │   ├── .obsidian\                     (Obsidian設定 - BOX同期、分離不要)
    │   ├── _inbox\                        (Triage Area)
    │   ├── Projects\                      (案件ごとのナレッジ)
    │   │   ├── 00_Projects-Index.md       (案件管理インデックス)
    │   │   ├── ProjectA\
    │   │   │   ├── daily\                 (Project Specific Log)
    │   │   │   ├── meetings\              (Meeting Notes)
    │   │   │   ├── specs\                 (Draft Specs)
    │   │   │   ├── notes\                 (雑多なメモ)
    │   │   │   ├── ProjectA-Links.md      (Link Collection)
    │   │   │   └── 00_ProjectA-Index.md   (Project Home)
    │   │   ├── ProjectB\
    │   │   └── _inHouse\                  (社内業務・プロジェクト外の記録)
    │   │       ├── daily\                 (日次メモ)
    │   │       ├── meetings\              (社内会議)
    │   │       ├── notes\                 (雑多なメモ)
    │   │       └── 00_inHouse-Index.md    (インハウスHome)
    │   ├── TechNotes\                     (技術メモ - 案件横断の知識ベース)
    │   │   ├── csharp\                    (C# メモ)
    │   │   ├── sql\                       (SQL メモ)
    │   │   ├── python\                    (Python メモ)
    │   │   ├── git\                       (Git メモ)
    │   │   ├── infra\                     (インフラ・ネットワーク)
    │   │   └── other\                     (その他)
    │   └── _templates\
    │       ├── project-daily-note.md
    │       ├── project-meta.md
    │       └── meeting-note.md
    │
    └── Projects\                          [Layer 3: Artifact - BOX Sync]
        └── ProjectA\               (個人使用・資料の用途別分類)
            ├── docs\                       (本筋ドキュメント - 作成・編集する)
            │   ├── planning\               (企画・要件定義・提案書)
            │   ├── design\                 (設計書 - 基本/詳細/データモデル/UI)
            │   ├── testing\                (テスト計画・ケース・結果)
            │   └── release\                (リリース・移行手順・環境構築)
            │
            ├── reference\                  (参考資料 - 読むだけ・保存用)
            │   ├── vendor\                 (ベンダー提供資料・仕様書)
            │   ├── standards\              (社内規約・標準・ガイドライン)
            │   └── external\               (その他外部資料・調査結果)
            │
            ├── records\                    (記録・履歴 - 証跡として残す)
            │   ├── minutes\                (議事録)
            │   ├── reports\                (進捗報告・ステークホルダー向け)
            │   └── reviews\                (レビュー記録・承認履歴)
            │
            └── _work\                     (日付ベースの作業フォルダ)
                └── 2026\
                    └── 01\
                        └── 25_XXXの件対応\
```

### 各レイヤーの運用詳細と分類理由

#### Layer 1: Execution (作業場)
- 場所: ローカル (`Documents/Projects/ProjectA`)
- 役割: 日々の作業、コーディング。`shared/` ジャンクション経由でLayer 3にアクセス。
- ローカル専用フォルダ:
    - `_ai-context`: 全AI共通のコンテキスト情報 (Obsidianジャンクション含む)。
    - `AGENTS.md` / `CLAUDE.md`: shared配下のマスターファイルからのコピー (BOX同期外)。
    - `_temp`: 一時ファイル・作業中の作業用。
    - `development/source`: Git管理。BOX同期しない(容量・競合回避)。
- `shared/`: BOX共有フォルダ全体をジャンクションでマウント。

#### Layer 2: Knowledge (思考の場)
- 場所: BOX内 Obsidian Vault
- 役割: 個人の思考整理、知見の蓄積、ドラフト作成。
- BOX同期リスク対策:
    - 設定分離不要: 現状、別フォルダ運用で問題が起きていないため、デフォルトの `.obsidian/` をそのままBOX同期する。
    - 同時起動禁止: 原則として、2台のPCで同時にObsidianを開かない(データ上書き防止)。
- フォルダ分類:
    - `Projects`: 案件ごとのナレッジフォルダ。デイリーノートは各プロジェクト配下の `daily/` に記録。
        - 構成: 案件ごとにフォルダを作成 (例: `ProjectA/`)
        - リンク集: `ProjectA/ProjectA-Links.md` に集約
        - 雑多なメモ: `ProjectA/notes/` に配置 (とりあえず置いておく場所)
        - 日次メモ: `ProjectA/daily/` に配置 (案件ごとの日誌)
    - `Projects/_inHouse`: プロジェクトに属さない社内業務の記録場所。他のプロジェクトと同じフォルダ構成(daily, meetings, notes)で運用。
    - `TechNotes`: 案件横断の技術メモ。技術カテゴリごとにサブフォルダを切る。
        - 例: `csharp/`, `sql/`, `python/`, `git/`, `infra/`
        - 各フォルダにメモファイル(.md)を配置。案件が終わっても残る知識はここに蓄積。

#### Layer 3: Artifact (成果物・参照)
- 場所: BOX内 `Projects/ProjectA`
- 役割: 個人使用のドキュメントと成果物の一元管理。
- ローカルとの統合: `shared/` ジャンクションで ProjectA/ 配下からアクセス。
- 運用:
    - **docs/**: 自分が作成・編集する本筋のドキュメント。企画からリリースまでの一連の資料。
    - **reference/**: 読むだけ・保存しておく資料。ベンダー仕様書や社内規約など。
    - **records/**: 証跡として残す記録。議事録や報告書、レビュー履歴など。
    - `_work/` に日付ベースの作業フォルダを作成 (例: `2026/01/25_XXXの件対応/`)。雑多な作業成果物はここに集約。
- 分類の考え方:
    - ファイルは作成時の性質に応じて配置するだけで、後から移動する必要はない。
    - 用途別に分類しているため、「どこに置くか」の判断が容易。

---

## 3. 実装手順 (Implementation Steps)

### Phase 1: フォルダ構造とリスクヘッジ

#### 1.1 BOXフォルダ作成

```powershell
# BOX Sync フォルダ内にObsidian Vault作成
$boxRoot = "$env:USERPROFILE\Box"
New-Item -Path "$boxRoot\Obsidian-Vault" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\_inbox" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\Projects" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\Projects\ProjectA" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\Projects\ProjectA\daily" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\Projects\_inHouse" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\Projects\_inHouse\daily" -ItemType Directory
New-Item -Path "$boxRoot\Obsidian-Vault\TechNotes" -ItemType Directory
@("csharp","sql","python","git","infra","other") | ForEach-Object {
    New-Item -Path "$boxRoot\Obsidian-Vault\TechNotes\$_" -ItemType Directory
}
New-Item -Path "$boxRoot\Obsidian-Vault\_templates" -ItemType Directory

# ProjectA共有フォルダ (Box/Projects 配下、サブフォルダ含む)
$projectsRoot = "$boxRoot\Projects"
$sharedSubs = @(
    "ProjectA",
    "ProjectA\docs\planning",
    "ProjectA\docs\design",
    "ProjectA\docs\testing",
    "ProjectA\docs\release",
    "ProjectA\reference\vendor",
    "ProjectA\reference\standards",
    "ProjectA\reference\external",
    "ProjectA\records\minutes",
    "ProjectA\records\reports",
    "ProjectA\records\reviews",
    "ProjectA\_work"
)
foreach ($sub in $sharedSubs) {
    New-Item -Path "$projectsRoot\$sub" -ItemType Directory -Force
}
```

#### 1.2 ローカルProjectフォルダ作成とジャンクション

ローカル `Documents/Projects/ProjectA/` に、以下の2本のジャンクションを作成する:
1. `shared/` → Box/Projects/ProjectA (Layer 3)
2. `_ai-context/obsidian_notes/` → Box/Obsidian-Vault/Projects/ProjectA (Layer 2)

さらに、AI指示書 (`AGENTS.md`) のシンボリックリンクを作成する。

```powershell
$docRoot = "$env:USERPROFILE\Documents\Projects\ProjectA"
$boxShared = "$env:USERPROFILE\Box\Projects\ProjectA"
New-Item -Path $docRoot -ItemType Directory -Force

# ローカル専用フォルダ作成
@("_ai-context", "_temp", "development\source", "development\config",
  "development\scripts") | ForEach-Object {
    New-Item -Path "$docRoot\$_" -ItemType Directory -Force
}

# ジャンクション作成 (2本)
# 1. shared/ -> Box/Projects/ProjectA (Layer 3: Artifact)
New-Item -ItemType Junction -Path "$docRoot\shared" -Target $boxShared

# 2. obsidian_notes/ -> Box/Obsidian-Vault/Projects/ProjectA (Layer 2: Knowledge)
$obsidianNotesDir = "$docRoot\_ai-context\obsidian_notes"
$obsidianTarget = "$env:USERPROFILE\Box\Obsidian-Vault\Projects\ProjectA"
New-Item -ItemType Junction -Path $obsidianNotesDir -Target $obsidianTarget
```

#### 1.3 セットアップスクリプト (setup_junctions.ps1)

初回セットアップおよびPC-Bでの環境構築に使用。
`Documents/Projects/ProjectA/scripts/setup_junctions.ps1` として保存。

```powershell
# ProjectA セットアップスクリプト (初回 / PC-B 共通)
$docRoot = "$env:USERPROFILE\Documents\Projects\ProjectA"
$boxShared = "$env:USERPROFILE\Box\Projects\ProjectA"

# ローカル専用フォルダ作成
$localFolders = @(
    "_ai-context", "_temp",
    "development\source", "development\config", "development\scripts"
)
foreach ($folder in $localFolders) {
    $path = "$docRoot\$folder"
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "ローカルフォルダ作成: $folder" -ForegroundColor Green
    }
}

# BOX共有フォルダ作成 (存在しない場合)
$sharedSubs = @(
    "docs\planning", "docs\design", "docs\testing", "docs\release",
    "reference\vendor", "reference\standards", "reference\external",
    "records\minutes", "records\reports", "records\reviews",
    "_work"
)
foreach ($sub in $sharedSubs) {
    $path = "$boxShared\$sub"
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "BOX共有フォルダ作成: $sub" -ForegroundColor Cyan
    }
}

# ジャンクション作成 (2本)

# 1. shared/ -> Box/Projects/ProjectA (Layer 3: Artifact)
$link = "$docRoot\shared"
if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "ジャンクション既存: shared/ -> $boxShared" -ForegroundColor Yellow
    } else {
        Write-Warning "shared/ が通常フォルダとして存在します。確認してください: $link"
    }
} elseif (Test-Path $boxShared) {
    New-Item -ItemType Junction -Path $link -Target $boxShared | Out-Null
    Write-Host "ジャンクション作成完了: shared/ -> $boxShared" -ForegroundColor Green
} else {
    Write-Warning "BOX共有フォルダが見つかりません: $boxShared"
    Write-Warning "Box同期が完了しているか確認してください。"
}

# 2. obsidian_notes/ -> Box/Obsidian-Vault/Projects/ProjectA (Layer 2: Knowledge)
$obsidianNotesDir = "$docRoot\_ai-context\obsidian_notes"
$obsidianTarget = "$env:USERPROFILE\Box\Obsidian-Vault\Projects\ProjectA"

if (-not (Test-Path "$docRoot\_ai-context")) {
    New-Item -Path "$docRoot\_ai-context" -ItemType Directory -Force | Out-Null
}

$obsidianLink = $obsidianNotesDir
if (Test-Path $obsidianLink) {
    $item = Get-Item $obsidianLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "ジャンクション既存: obsidian_notes/ -> $obsidianTarget" -ForegroundColor Yellow
    } else {
        Write-Warning "obsidian_notes/ が通常フォルダとして存在します。確認してください: $obsidianLink"
    }
} elseif (Test-Path $obsidianTarget) {
    New-Item -ItemType Junction -Path $obsidianLink -Target $obsidianTarget | Out-Null
    Write-Host "ジャンクション作成完了: obsidian_notes/ -> $obsidianTarget" -ForegroundColor Green
} else {
    Write-Warning "Obsidian Vaultフォルダが見つかりません: $obsidianTarget"
    Write-Warning "Box同期が完了しているか確認してください。"
}

Write-Host "`nセットアップ完了" -ForegroundColor Green
```

#### 1.4 ローカル専用フォルダの保持

以下はローカルに残す (ジャンクションではなく実フォルダ):
- %USERPROFILE%\Documents\Projects\ProjectA\_ai-context
- %USERPROFILE%\Documents\Projects\ProjectA\_temp
- %USERPROFILE%\Documents\Projects\ProjectA\development

#### 1.5 設定ファイルテンプレート作成

`Documents/Projects/ProjectA/scripts/config/.env.example`:

```bash
# Asana API設定
ASANA_TOKEN=your_personal_access_token_here
ASANA_WORKSPACE_GID=your_workspace_gid_here
ASANA_PROJECT_GID=your_project_gid_here

# 出力設定
ASANA_OUTPUT_FILE=../asana-tasks-view.md
```

`Documents/Projects/ProjectA/scripts/config/config.template.json`:

```json
{
  "asana": {
    "token": "your_personal_access_token_here",
    "workspace_gid": "your_workspace_gid_here",
    "project_gid": "your_project_gid_here"
  },
  "output": {
    "file": "../asana-tasks-view.md",
    "format": "markdown"
  }
}
```

#### 1.6 健全性チェックスクリプト

`Documents/Projects/ProjectA/scripts/check_symlinks.ps1` を作成し、ジャンクション確認と.lnkリンク切れを検知する。

```powershell
# ProjectA 健全性チェックスクリプト
$docRoot = "$env:USERPROFILE\Documents\Projects\ProjectA"
$boxShared = "$env:USERPROFILE\Box\Projects\ProjectA"

Write-Host "=== ProjectA Health Check ===" -ForegroundColor Cyan

# ジャンクション確認
Write-Host "`n[Junction]" -ForegroundColor Yellow
$link = "$docRoot\shared"
if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "OK: shared/ -> $boxShared" -ForegroundColor Green
    } else {
        Write-Warning "shared/ はジャンクションではなく通常フォルダです"
    }
} else {
    Write-Warning "shared/ が存在しません。setup_junctions.ps1 を実行してください"
}

# シンボリックリンク確認 (手動作成分、BOX非同期)
Write-Host "`n[Symlinks (.lnk) - PC固有、BOX非同期]" -ForegroundColor Yellow
$shell = New-Object -ComObject WScript.Shell
$lnkFiles = Get-ChildItem -Path $boxShared -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue

if ($lnkFiles) {
    Write-Host "※ シンボリックリンクはBOX同期されません。各PCで個別に作成してください。" -ForegroundColor DarkYellow
    foreach ($lnk in $lnkFiles) {
        $shortcut = $shell.CreateShortcut($lnk.FullName)
        $target = $shortcut.TargetPath
        if (-not (Test-Path $target)) {
            Write-Warning "リンク切れ: $($lnk.FullName) -> $target"
        } else {
            Write-Host "OK: $($lnk.Name)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "(.lnk ファイルなし)" -ForegroundColor Gray
}

Write-Host "`nチェック完了" -ForegroundColor Cyan
```

#### 1.7 新規プロジェクトの作成 (テンプレート活用)

新規プロジェクトを作成する場合は、`_projectTemplate` を使用して標準的な構造を自動生成できます。

**使用例:**

```powershell
# テンプレートディレクトリに移動
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# 新規プロジェクトを作成 (new構造)
.\setup_project.ps1 -ProjectName "MyNewProject"

# または、legacy構造を使用する場合
.\setup_project.ps1 -ProjectName "MyNewProject" -Structure legacy
```

**ProjectA と新規プロジェクトの違い:**

| 項目 | ProjectA (本ドキュメント) | 新規プロジェクト (_projectTemplate) |
|------|---------------------------|-------------------------------------|
| スクリプト | 専用スクリプト (setup_junctions.ps1等) | 汎用スクリプト (setup_project.ps1) |
| 構造 | new構造のみ | new/legacy 両対応 |
| Obsidian連携 | 手動で記述 | 自動でジャンクション作成 |
| 設定ファイル | .env.example, config.template.json | config.json (自動生成) |

**テンプレートの利点:**
- プロジェクト名を指定するだけで、フォルダ構造とジャンクションが自動作成される
- 新規/旧来の2種類の構造から選択可能
- Obsidian Vault との連携も自動設定 (Indexファイル自動作成含む)
- 健全性チェックスクリプトも同梱

**テンプレートの場所:**
- `%USERPROFILE%\Documents\Projects\_projectTemplate\`
- 詳細は `_projectTemplate\README.md` を参照

### Phase 1.5: Multi-CLI 対応

本アーキテクチャでは、単一の指示書 (`AGENTS.md`) で複数のAI CLIツールに対応します。

#### 対応ツールと設定

| CLI Tool | 参照ファイル | 設定方法 |
|----------|------------|----------|
| **Claude Code** | `CLAUDE.md` | `CLAUDE.md` を `AGENTS.md` へのシンボリックリンクとして配置 |
| **Codex CLI** | `AGENTS.md` | ネイティブ対応 (`AGENTS.md` を直接読み込み) |
| **Gemini CLI** | `AGENTS.md` | ネイティブ対応 (Gemini CLIは `AGENTS.md` を認識可能) |

#### 実装詳細

1. **Master Instruction**: `shared/AGENTS.md` (BOX同期)
2. **Shared Alias**: `shared/CLAUDE.md` (BOX同期 - Copy of AGENTS.md)
3. **Local Copies**:
   - `ProjectA/AGENTS.md` (Copy from shared)
   - `ProjectA/CLAUDE.md` (Copy from shared)
3. **Context**: `_ai-context/` フォルダに必要な情報を集約し、`AGENTS.md` 内で「このフォルダを参照せよ」と指示する。

### Phase 2: Obsidian Vault の設定

#### 2.1 Obsidian初期設定

1. Obsidianを起動
2. "Open folder as vault" → %USERPROFILE%\Box\Obsidian-Vault
3. Trust Author (信頼)

#### 2.2 Vault構成ファイルの作成

`Projects/00_Projects-Index.md` (案件管理インデックス)

```markdown
# 案件管理インデックス

## 進行中の案件
- [[00_ProjectA-Index|ProjectA: システム導入案件]] (2026/01-2026/12) #system-deployment #phase-planning
- [[00_ProjectB-Index|ProjectB]] #data-migration
- [[00_ProjectC-Index|ProjectC]] #infrastructure
- [[00_inHouse-Index|_inHouse: 社内業務]] #inhouse

## 案件別アクセス
- #ProjectA - システム導入案件
- #ProjectB - データ移行
- #ProjectC - インフラ整備
- #inhouse - 社内業務・プロジェクト外

## タグ一覧
- フェーズ: #phase-planning #phase-design #phase-dev #phase-test #phase-deployment
- ステータス: #status-active #status-blocked #status-review #status-completed
- 優先度: #priority-critical #priority-high #priority-normal #priority-low

## デイリーノートからのアクセス
- [[Projects/ProjectA/daily/2026-02-11|今日の作業ログ]]
```

`Projects/ProjectA/00_ProjectA-Index.md` (案件HP)

```markdown
# ProjectA: システム導入案件

## 基本情報
- プロジェクト名: ProjectA
- 期間: 2026/01/01 - 2026/12/31
- 対象システム: 新規システム導入
- 現在フェーズ: 要件定義 #phase-planning
- タグ: #ProjectA #system-deployment

## 外部リソース

### ローカルフォルダ
- CLAUDE.md: (Legacy) `file:///%USERPROFILE%/Documents/Projects/ProjectA/CLAUDE.md`
- AGENTS.md: `file:///%USERPROFILE%/Documents/Projects/ProjectA/AGENTS.md` - **Instruction Master**
- マスタースケジュール: `file:///%USERPROFILE%/Documents/Projects/ProjectA/shared/docs/planning/master-schedule.md`

### Gitリポジトリ
- ソースコード: `file:///%USERPROFILE%/Documents/Projects/ProjectA/development/source/`
- GitHub: (リポジトリURLを記載)

### Asana
- プロジェクトURL: (AsanaのProjectAプロジェクトURL)
- タスクリスト: (主要なタスクリストURL)

## 主要ドキュメント
- [[ProjectA-Requirements]] - 要件定義
- [[ProjectA-Architecture]] - アーキテクチャ
- [[ProjectA-Schedule]] - スケジュール管理

## 関連デイリーノート
- デイリーノートで #ProjectA タグで検索
- バックリンクでこのページを参照しているノートを表示

## 週次サマリー
- [[ProjectA-Weekly-2026-W06]]
- [[ProjectA-Weekly-2026-W07]]
```

#### 2.3 テンプレート設定

A. プロジェクト用 (`_templates/project-daily-note.md`)
ProjectA/daily/YYYY-MM-DD.md として作成時に適用

```markdown
# {{date:YYYY-MM-DD}}

## 今日のタスク (Asana Sync)
- [ ] <!-- Asanaタスク貼付エリア -->

## 進捗メモ
-

## 明日の予定
- [ ]

## リスク・ブロッカー
-

---
tags: #daily #ProjectA
```

B. _inHouse用 (`_templates/inhouse-daily-note.md`)
_inHouse/daily/YYYY-MM-DD.md として作成時に適用

```markdown
# {{date:YYYY-MM-DD}}

## 今日のタスク
- [ ]

## メモ
-

---
tags: #daily #inhouse
```

#### 2.4 Obsidian プラグイン推奨設定

推奨コアプラグイン:
- Daily notes (日次ノート)
- Templates (テンプレート)
- Backlinks (バックリンク)
- Graph view (グラフビュー)
- Tag pane (タグペイン)

推奨コミュニティプラグイン:
- Calendar (カレンダービュー)
- Dataview (データクエリ)
- Templater (高度なテンプレート)

### Phase 3: Git リポジトリの設定

#### 3.1 Gitリポジトリ初期化

```bash
cd "$env:USERPROFILE\Documents\Projects\ProjectA\development\source"
git init
```

#### 3.2 .gitignore 設定

`Documents/Projects/ProjectA/development/source/.gitignore`:

```
# ビルド成果物
/bin/
/obj/
/out/
/build/

# IDE設定
.vscode/
.vs/
*.suo
*.user

# 環境変数・機密情報
.env
.env.local
config/local.json

# ログファイル
*.log

# OS固有
Thumbs.db
.DS_Store

# 一時ファイル
*.tmp
*.swp
```

#### 3.3 リモートリポジトリ設定 (GitHub例)

```bash
# GitHubでリポジトリ作成後
git remote add origin https://github.com/[your-account]/ProjectA-source.git
git branch -M main

# 初回コミット
git add .
git commit -m "Initial commit: ProjectA source code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push -u origin main
```

### Phase 4: Asana 統合 (One-way Sync)

方針: Asana(正) -> Obsidian(Markdown View) の一方通行同期。
メモ的なサブタスクのみMarkdownで管理し、タスク自体の追加・ステータス変更はAsanaで行う。

### Phase 4.5: 週次サマリー生成 (Weekly Summary)

週次サマリーは weekly-summary Skill を使用して自動生成する。

**Skillの場所:** `Box/Obsidian-Vault/.claude/skills/weekly-summary/SKILL.md`

**使用方法:**
- 毎週金曜夕方、Claudeに「今週のサマリーを作成して」と依頼
- Skillが以下を自動実行:
  1. デイリーノートから今週の記録を収集
  2. Asanaタスク状況を参照
  3. サマリーを生成
  4. `Box/Obsidian-Vault/Projects/ProjectA/weekly/ProjectA-Weekly-YYYY-WXX.md` に保存
  5. `00_ProjectA-Index.md` にリンクを追加

**手動作成時の保存先:**
```
Box/Obsidian-Vault/Projects/ProjectA/weekly/
├── ProjectA-Weekly-2026-W06.md
├── ProjectA-Weekly-2026-W07.md
└── ...
```

#### 4.1 Asana ワークスペース セットアップ

1. Asanaで新規プロジェクト作成:
   - プロジェクト名: "ProjectA - システム導入案件"
   - ビュー: リスト + ボード + タイムライン

2. セクション作成:
   - 01-Planning (企画)
   - 02-Design (設計)
   - 03-Development (開発)
   - 04-Testing (テスト)
   - 05-Deployment (デプロイ)
   - 06-Operation (運用)

3. カスタムフィールド設定:
   - フェーズ (ドロップダウン): Planning, Design, Dev, Test, Deploy, Operation
   - 優先度 (ドロップダウン): Critical, High, Normal, Low
   - MD_Path (テキスト): ローカルMarkdownファイルのパス
   - Sync_Status (ドロップダウン): Pending, Synced, Conflict

#### 4.2 Asana API トークン取得

1. Asana → Settings → Apps → Developer apps
2. "Create new personal access token"
3. トークンをコピー

#### 4.3 同期スクリプト (sync_from_asana.py)

必要パッケージ (`requirements.txt`):

```
asana>=5.0.0
python-frontmatter>=1.1.0
```

設定: 環境変数 `ASANA_TOKEN`, `ASANA_WORKSPACE_GID`, `ASANA_OUTPUT_FILE` または `config.json`

実行: `python %USERPROFILE%\Documents\Projects\_globalScripts\sync_from_asana.py`

スクリプト本体は `Documents/Projects/_globalScripts/sync_from_asana.py` を参照。

**週次実行**: 毎週金曜夕方、上記コマンドを直接実行してください。

### Phase 5: 動作確認

#### 5.1 Obsidian動作確認

- [ ] Obsidian VaultをBOXフォルダで開く
- [ ] ProjectA/daily/ に新規日次ノート作成 (テンプレートA適用)
- [ ] 00_ProjectA-Index.md から file:/// リンク動作確認
- [ ] タグ検索で #ProjectA 絞り込み確認
- [ ] グラフビューで案件関連表示確認
- [ ] PC-B (2台目) でBOX同期後、Obsidian起動確認

#### 5.2 BOX同期確認

- [ ] ProjectA/ にテストファイル作成
- [ ] PC-Aで編集 → PC-Bで同期確認
- [ ] ジャンクション経由で Documents\ProjectA\shared\docs\planning アクセス確認

#### 5.3 Git動作確認

- [ ] テストファイル作成・コミット
- [ ] リモートリポジトリへプッシュ
- [ ] PC-Bでクローン or プル
- [ ] .gitignore 動作確認

#### 5.4 Asana同期確認

- [ ] Asanaでテストタスク作成
- [ ] sync_from_asana.py 実行
- [ ] 出力Markdownファイル確認

---

## 4. 運用フロー

### 毎日の作業 (10分)

1. Obsidian起動
2. デイリーノート作成 (Ctrl+T または Command Palette → "Daily note")
3. ProjectA セクションにタスク・メモ記録
4. #ProjectA タグ付与

### 週次作業 (30分 - 金曜夕方)

1. Asana同期スクリプト実行: `python %USERPROFILE%\Documents\Projects\_globalScripts\sync_from_asana.py`
2. Asanaタスク状況を確認
3. 週次サマリー作成 (weekly-summary Skillを使用)

---

## 5. 段階的な移行計画

現在のProjectAフォルダ構造から新構成への移行は一度に行わず、段階的に実施:

### Week 1: Obsidian Vault セットアップ

- BOXフォルダにVault作成
- テンプレート・MOC作成
- デイリーノート運用開始 (既存daily/と並行)

### Week 2: BOX同期フォルダ移行

- ProjectA/ へフォルダ移動
- shared/ ジャンクション作成
- 動作確認

### Week 3: Git リポジトリ設定

- リポジトリ初期化
- リモート設定
- 初回コミット・プッシュ

### Week 4: Asana統合

- Asana プロジェクト作成
- 同期スクリプト作成
- 週次同期運用開始

### Week 5 以降: 最適化

- daily/ の旧形式データをObsidian Vaultへ統合検討
- Asana自動同期の検討 (MCP Server導入)
- 運用ルールの見直し

---

## 6. 期待される効果

- 2PC間のシームレスな同期 (BOX + Git)
- 複数案件の一元管理 (Obsidian Vault)
- タグ・バックリンクによる情報整理
- AI協働とAsanaの両立 (軽量統合)
- ソースコードの適切なバージョン管理 (Git)
- 容量問題の解決 (ソースコードはBOX非同期)

---

## 7. 技術的な注意点と対策

### 1. Obsidian Vault の BOX 同期リスク

課題: .obsidian/ フォルダが2PC間で同期されると、設定の競合が発生する可能性

現状: 別フォルダ運用で問題が起きていないため、設定分離はしない。デフォルトの `.obsidian/` をそのままBOX同期する。

対策:
- 両PCで同時に設定変更しない
- 競合発生時は最新版を確認して手動マージ
- 重大な競合の場合は片方の .obsidian/ を削除して再同期

### 2. Git リポジトリと BOX の競合

課題: .git/ フォルダをBOX同期すると、リポジトリが破損する可能性

対策:
- development/source/ はローカル管理 (BOX非同期)
- Gitリモートリポジトリで2PC間同期

### 3. ジャンクションの制約

注意点:
- ジャンクションは同一ボリューム内のみ
- リンク先のフォルダを移動・削除するとジャンクション無効化
- PC-Bでは setup_junctions.ps1 でジャンクション再作成が必要
- ジャンクションは2本:
  - `shared/` → Box/Projects/ProjectA (成果物)
  - `_ai-context/obsidian_notes/` → Box/Obsidian-Vault/Projects/ProjectA (知識ベース)

### 4. Asana API レート制限

制限:
- 1分あたり150リクエスト
- 1時間あたり1,500リクエスト

対策:
- 週次手動同期なので問題なし
- 自動化する場合はレート制限を考慮

### 5. BOXとシンボリックリンクの制約

- BOXはシンボリックリンク (.lnk) を同期しない。
- Shared配下のシンボリックリンクは手動作成・PC固有である。
- 2PC間で同じリンクが必要な場合は各PCで個別に作成する。
- リンク切れの確認は `check_symlinks.ps1` で実施する。

---

## 8. プロジェクトのアーカイブ

完了したプロジェクトは、3層すべてを `_archive/` フォルダに移動して保管する。
ファイルは削除せず、アクティブな領域から分離することで検索ノイズを減らす。

### アーカイブ後のフォルダ構成

```
Documents/Projects/
├── _archive/
│   └── ProjectX/              (Layer 1: ジャンクション解除済み)
├── ProjectA/                  (進行中)
└── ...

Box/Projects/
├── _archive/
│   └── ProjectX/              (Layer 3: 成果物保管)
├── ProjectA/                  (進行中)
└── ...

Box/Obsidian-Vault/Projects/
├── _archive/
│   └── ProjectX/              (Layer 2: ナレッジ保管)
├── ProjectA/                  (進行中)
└── ...
```

### アーカイブ手順

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# DryRunで確認 (実際には何も変更しない)
.\archive_project.ps1 -ProjectName "ProjectX" -DryRun

# 問題なければ実行
.\archive_project.ps1 -ProjectName "ProjectX"
```

スクリプトが自動実行する内容:
1. ジャンクション (shared/, obsidian_notes/) とAGENTS.md/CLAUDE.mdシンボリックリンクを安全に解除
2. Layer 3 (BOX成果物) を `Box/Projects/_archive/` に移動
3. Layer 2 (Obsidianナレッジ) を `Box/Obsidian-Vault/Projects/_archive/` に移動
4. Layer 1 (ローカル) を `Documents/Projects/_archive/` に移動

### アーカイブ後のチェックリスト

- [ ] `00_Projects-Index.md` のエントリを「アーカイブ済み」セクションに移動
- [ ] Gitリモートに最終pushが完了しているか確認
- [ ] `TechNotes/` に昇格すべき汎用的な知見がないか棚卸し
- [ ] Asanaプロジェクトのステータスを「完了」に更新

### アーカイブの復元

復元が必要な場合は、`_archive/` から元の場所にフォルダを戻し、`setup_project.ps1` でジャンクションを再作成する:

```powershell
# 1. フォルダを元の場所に移動 (手動)
# 2. ジャンクションを再作成
.\setup_project.ps1 -ProjectName "ProjectX"
```

### Obsidianでの扱い

- `_archive/` 配下のノートはグラフビューでグループ分けして色を変えると視認性が上がる
- Dataviewクエリで `_archive/` を除外するフィルタを入れると日常の検索ノイズが減る
  - 例: `WHERE !contains(file.path, "_archive")`
- BOX Driveを使用している場合、`_archive/` のオフライン設定を外すとローカルディスク容量を節約できる

---

## 9. Support プロジェクト管理 (mini tier)

お手伝い系プロジェクトやメイン案件ほどの構成が不要なプロジェクトには、軽量構成 (mini tier) を使用できます。
mini tier のプロジェクトは `_mini/` 配下に配置され、フル機能のメイン案件と視覚的に分離されます。

### Tier 比較

| 項目 | full tier (メイン案件) | mini tier (お手伝い系) |
|------|----------------------|----------------------|
| 配置先 | `Projects/{案件}/` | `Projects/_mini/{案件}/` |
| 用途 | メイン案件 (長期、複雑) | お手伝い系 (短期、シンプル) |
| Layer 1 (_ai-workspace/) | あり | なし |
| Layer 1 (scripts/config/) | あり | なし |
| Layer 2 (Obsidian) | daily, meetings, specs, notes, weekly | notes のみ |
| Layer 3 (BOX docs/) | 構造化 (planning, design, testing, release) | flat (サブフォルダなし) |
| Layer 3 (reference/) | あり | なし |
| Layer 3 (records/) | あり | なし |
| Layer 3 (_work/) | あり | あり |
| Structure パラメータ | new / legacy 選択可能 | 無視 (flat のみ) |

### mini tier のフォルダ構成

```
Documents/Projects/_mini/{ProjectName}/
├── _ai-context/                      # Commmon Context [Local]
│   └── obsidian_notes/               ← Junction → Box/Obsidian-Vault/Projects/_mini/{ProjectName}
│
├── development/                      # 開発関連 [Local]
│   ├── source/                       # ソースコード (Git管理)
│   ├── config.json                   # Project configuration
│   └── config/                       # Additional config files
│
├── shared/                           ← Junction → Box/Projects/_mini/{ProjectName}
│
├── AGENTS.md                         # Copy from shared/AGENTS.md
└── CLAUDE.md                         # Copy from shared/AGENTS.md

Box/Projects/_mini/{ProjectName}/
├── AGENTS.md                         # プロジェクト固有AI指示書 (実体 - Master)
├── docs/                             # ドキュメント (flat - サブフォルダなし)
└── _work/                            # 作業フォルダ

Box/Obsidian-Vault/Projects/_mini/{ProjectName}/
├── notes/                            # ノート
└── 00_{ProjectName}-Index.md        # プロジェクトインデックス
```

### mini tier プロジェクトの作成

```powershell
cd %USERPROFILE%\Documents\Projects\_projectTemplate\scripts

# お手伝い系プロジェクトのセットアップ
.\setup_project.ps1 -ProjectName "SupportProject" -Tier mini
```

### mini tier の運用ルール

1. ドキュメント配置: `shared/docs/` に flat 配置 (サブフォルダなし)
2. Obsidian ノート: `notes/` フォルダのみ使用 (daily, weekly 不要)
3. 健全性チェック: `check_project.ps1 -ProjectName "SupportProject" -Support`
4. アーカイブ: `archive_project.ps1 -ProjectName "SupportProject" -Support`

### Obsidian での扱い

- `_mini/` 配下のプロジェクトはグラフビューで色分けして識別しやすくする
- Dataview でフィルタ可能: `WHERE contains(file.path, "_mini")`
- `00_Projects-Index.md` に「お手伝い系プロジェクト」セクションを作成して管理

### アーカイブ先

mini tier のプロジェクトは、アーカイブ時に `_archive/_mini/` 配下に移動されます:

```
Documents/Projects/_archive/_mini/{ProjectName}/
Box/Projects/_archive/_mini/{ProjectName}/
Box/Obsidian-Vault/Projects/_archive/_mini/{ProjectName}/
```

---

## 10. クリティカルなファイル

### 作成・編集が必要なファイル

1. %USERPROFILE%\Box\Obsidian-Vault\Projects\00_Projects-Index.md
2. %USERPROFILE%\Box\Obsidian-Vault\Projects\ProjectA\00_ProjectA-Index.md
3. %USERPROFILE%\Box\Obsidian-Vault\Projects\_inHouse\00_inHouse-Index.md
4. %USERPROFILE%\Box\Obsidian-Vault\_templates\project-daily-note.md
5. %USERPROFILE%\Box\Obsidian-Vault\_templates\inhouse-daily-note.md
6. %USERPROFILE%\Documents\Projects\ProjectA\scripts\setup_junctions.ps1
7. %USERPROFILE%\Documents\Projects\ProjectA\scripts\check_symlinks.ps1
8. %USERPROFILE%\Documents\Projects\_globalScripts\sync_from_asana.py
9. %USERPROFILE%\Documents\Projects\ProjectA\development\source\.gitignore
11. %USERPROFILE%\Documents\Projects\ProjectA\AGENTS.md (via Symlink from shared/)
12. %USERPROFILE%\Documents\Projects\ProjectA\scripts\config\.env.example
13. %USERPROFILE%\Documents\Projects\ProjectA\scripts\config\config.template.json
14. %USERPROFILE%\Box\Obsidian-Vault\.claude\skills\weekly-summary\SKILL.md

### 既存ファイルの活用

- %USERPROFILE%\Documents\Projects\ProjectA\shared\docs\planning\master-schedule.md (ジャンクション経由)
- %USERPROFILE%\Documents\Projects\ProjectA\.claude\context\system-overview.md
- %USERPROFILE%\Documents\Projects\ProjectA\.claude\context\glossary.md

### 新規プロジェクト作成用テンプレート

新規プロジェクトを作成する際は、以下のテンプレートを使用してください:

| ファイル | 用途 |
|---------|------|
| `%USERPROFILE%\Documents\Projects\_projectTemplate\README.md` | テンプレートの使用方法 |
| `%USERPROFILE%\Documents\Projects\_projectTemplate\CLAUDE.md` | 新規プロジェクト用AGENTS.mdテンプレート |
| `%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\setup_project.ps1` | プロジェクトセットアップスクリプト |
| `%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\check_project.ps1` | 健全性チェックスクリプト |
| `%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\archive_project.ps1` | プロジェクトアーカイブスクリプト |
| `%USERPROFILE%\Documents\Projects\_projectTemplate\scripts\config.template.json` | 設定ファイルテンプレート |

**注意:** `_projectTemplate` 自体を編集しないでください。新規プロジェクト作成時にこのテンプレートからコピーして使用してください。
