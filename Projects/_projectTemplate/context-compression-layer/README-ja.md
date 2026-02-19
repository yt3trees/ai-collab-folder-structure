# Context Compression Layer

Obsidian Vault(Layer 2)に蓄積された膨大な知識を、AIが即座に把握できるよう圧縮した中間層。

```
Layer 1: Execution (WIP)     <- AIが作業する場所
Layer 2: Knowledge (Vault)   <- 知識の源泉(膨大)
  ↓ 圧縮
★ Context Compression Layer  <- AIが"今"を理解するためのレンズ
Layer 3: Artifact (BOX)      <- 成果物
```

## なぜ必要か

- AIは毎回コンテキストを忘れる -> 圧縮された「現在地」を毎回読ませる
- Vault全体を読ませると精度が落ちる -> 必要な情報だけ凝縮
- AIが関与しない作業がある -> 人間が書いた「今やってること」をAIが読む
- 長期プロジェクトの文脈が途切れる -> decision_logで判断の継続性を担保

## 構成

### プロジェクト個別(`_ai-context/` を拡張)

```
{ProjectName}/
├── _ai-context/
│   ├── project_summary.md     ★ プロジェクト全体像
│   ├── current_focus.md       ★ 今のフォーカス(人間が主に書く)
│   ├── focus_history/         ★ current_focus.md の日次スナップショット
│   ├── decision_log/          ★ 意思決定ログ
│   │   └── TEMPLATE.md
│   └── obsidian_notes/        (既存。触らない)
├── CLAUDE.md                  (既存。CCL指示を追記)
```

### ワークスペース全体(任意)

```
Documents/Projects/
├── .context/
│   ├── workspace_summary.md   ワークスペース概要
│   ├── current_focus.md       今週のフォーカス
│   └── active_projects.md     プロジェクト一覧と状態
├── CLAUDE.md                  (既存。CCL指示を追記)
```

## 誰が何を書くか

| ファイル | 人間 | AI |
|---------|------|-----|
| current_focus.md | 主に書く(30秒で上書き更新) | 作業の区切りで `[AI]` 付き追記を提案 |
| project_summary.md | 初期作成+大きな変更時 | マイルストーン変更時に更新提案 |
| decision_log/*.md | 会議等で決まったことを伝える | ドラフト生成。人間が承認して保存 |

### current_focus.md の運用

上書き運用。常に10-20行で「今のスナップショット」を保つ。

- 終わったタスク -> 消す
- 古い「最近あったこと」 -> 消す(直近1-2週間分だけ残す)
- 履歴が必要なもの -> decision_log / Obsidian Vault / gitログが担う
- 日次スナップショットは `save_focus_snapshot.ps1` で `focus_history/YYYY-MM-DD.md` に保存される

## 導入手順

### Step 1: CLAUDE.md に追記(これだけで動く)

`templates/CLAUDE_MD_SNIPPET.md` の内容をプロジェクトのCLAUDE.mdに追記。

### Step 2: current_focus.md を作成

`_ai-context/current_focus.md` に今やっていることを箇条書きで書く。

### Step 3: project_summary.md を作成

AIに下書きさせてOK。後から修正できる。

### Step 4: Agent Skills を配置(任意)

```bash
# スキルをClaude Codeに配置
cp -r skills/context-init ~/.claude/skills/
cp -r skills/context-session-end ~/.claude/skills/
cp -r skills/context-decision-log ~/.claude/skills/
```

Step 1-2だけで基本機能は動く。スキルは便利機能の追加。

## 自動化のレベル

| レベル | やること | 効果 |
|--------|---------|------|
| 0 | current_focus.md を手動で書くだけ | AIが今を把握できるようになる |
| 1 | CLAUDE.md に指示を追記 | AIが自動で読み込み+鮮度チェック |
| 2 | Agent Skills 導入 | decision_log自動生成、セッション終了時の追記提案 |
| 3 | Claude Code Hooks | current_focus.mdの鮮度警告を完全自動化 |

## Agent Skills 一覧

| スキル | 役割 | トリガー |
|--------|------|---------|
| context-init | CCL導入・初期化 | 「コンテキスト層を作って」(初回のみ) |
| context-session-end | 作業区切りでAI作業分を追記提案 | 自然な区切り(「ありがとう」「一旦ここまで」等) |
| context-decision-log | 意思決定の構造化記録+暗黙的決定の検出 | 決定時 or 検出時 |

スキルにしなかったもの:
- セッション開始の読み込み -> CLAUDE.mdの指示で十分
- 暗黙的決定の検出 -> decision-logスキルに統合

## ファイル構成

```
context-compression-layer/
├── README.md                           English documentation
├── README-ja.md                        このファイル
├── templates/
│   ├── CLAUDE_MD_SNIPPET.md            ★最重要: CLAUDE.mdに追記する内容
│   ├── current_focus.md                人間が書く軽量テンプレート
│   ├── project_summary.md             プロジェクト概要
│   ├── decision_log_TEMPLATE.md       意思決定ログ
│   ├── workspace_summary.md           ワークスペース概要(任意)
│   └── active_projects.md             プロジェクト一覧(任意)
├── examples/
│   ├── current_focus_example.md
│   ├── project_summary_example.md
│   └── decision_log_example.md
├── skills/
│   ├── context-init/SKILL.md
│   ├── context-session-end/SKILL.md
│   └── context-decision-log/SKILL.md
├── setup_context_layer.ps1            Setup script
└── save_focus_snapshot.ps1            current_focus.md の日次スナップショット保存
```
