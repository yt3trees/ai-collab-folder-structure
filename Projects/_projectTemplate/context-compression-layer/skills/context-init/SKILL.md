---
name: context-init
description: Implement a Context Compression Layer in the project. Use it for phrases like "Create a context layer" or "AI context settings." Fill in the initial content interactively and add an instruction to automatically load it into CLAUDE.md.
---

# Context Init

Context Compression Layerをプロジェクトに導入・初期化するスキル。

## 作成するもの

```
_ai-context/
├── project_summary.md       プロジェクト全体像
├── current_focus.md          今のフォーカス（人間が主に書く）
├── decision_log/             意思決定ログ
│   └── TEMPLATE.md
└── obsidian_notes/           既存のまま（触らない）
```

## 手順

### 1. 現状確認

- `_ai-context/` の有無
- CLAUDE.md / AGENTS.md の有無
- Tier（full / mini）

### 2. ユーザーに質問して記入

#### project_summary.md

```
project_summary.md を作ります。教えてください:

1. このプロジェクトの目的は？（1-2文で）
2. 技術スタックは？
3. 今のフェーズは？（設計/実装/テスト等）
4. AIに知っておいてほしいルールや制約は？

全部答えなくてもOK。わかる範囲で。後から更新できます。
```

#### current_focus.md

```
current_focus.md を作ります。
今一番注力していることは何ですか？（箇条書きでOK）
```

回答をテンプレートに流し込む:

```markdown
# Focus

## 今やってること

- {回答}

## 最近あったこと

- 

## 次やること

- 

## メモ

- 

---
更新: {今日の日付}
```

#### decision_log/

TEMPLATE.md を配置するだけ。初期ログは作らない。

### 3. CLAUDE.md への追記

既存の CLAUDE.md の末尾に以下を追記（既存内容は一切変更しない）:

```markdown
## Context Compression Layer

### 初回読み込み（自動）

このプロジェクトで最初のタスクに取りかかる前に、以下を読んでください:

1. `_ai-context/project_summary.md` - プロジェクト全体像
2. `_ai-context/current_focus.md` - 現在のフォーカス
3. `_ai-context/decision_log/` の最新3件（日付降順）

current_focus.md の末尾「更新」日付が3日以上前の場合、1回だけ聞いてください:
「前回から何か進展や変更はありましたか？（なければそのまま作業に入ります）」
回答があれば current_focus.md に反映してから作業開始。なければそのまま開始。

### 作業中

重要な意思決定（技術選定、設計判断、方針変更）があったら、1行で提案してください:
「💡 Decision Logに記録しますか？ → {決定の要約}」
承認されたら `_ai-context/decision_log/YYYY-MM-DD_topic.md` をTEMPLATEに従い作成。
1セッションで最大3回まで。断られたらそれ以上勧めない。

### 作業の区切り

まとまった作業が一段落したら、AI作業分を current_focus.md に追記提案してください:
- 既存の内容は触らない
- AIが追記する行には [AI] をつける
- 3-5行以内で簡潔に
- 短い質問応答だけの場合は提案不要
```

CLAUDE.md が存在しない場合は新規作成。

### 4. 完了報告

```
✅ Context Compression Layer 導入完了

作成: _ai-context/project_summary.md, current_focus.md, decision_log/
CLAUDE.md に自動読み込み指示を追記済み。

次回からAIが自動でコンテキストを読み込みます。
current_focus.md は作業の区切りで上書き更新してください（30秒で書ける設計です）。
```

## Mini Tier

必須: `current_focus.md` のみ。
任意: `project_summary.md`, `decision_log/`。

## ワークスペース全体用

`.context/` に `workspace_summary.md`, `current_focus.md`, `active_projects.md` を作成。
手順はプロジェクト個別と同じ。CLAUDE.md への追記内容が異なる。

## 既存プロジェクトへの後付け

既存ファイル・junctionには一切触れない。新規ファイルを追加し、CLAUDE.mdに追記するだけ。
