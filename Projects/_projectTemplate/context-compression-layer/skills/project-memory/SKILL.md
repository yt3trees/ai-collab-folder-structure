---
name: project-memory
description: AI behavioral guideline for autonomously managing project-specific knowledge. The AI proactively saves valuable insights discovered during work and searches existing memories when relevant context might exist, without requiring explicit commands.
---

# Project Memory

プロジェクト固有のメモリ。AIが作業中に発見した知見を自律的に記録・検索する行動規範。

## 基本方針

ユーザーが「覚えておいて」と言うのを待たない。AIは作業中に再利用価値のある知見を発見したら自分から保存を提案し、関連する既存の知見がありそうなときは自分から検索する。

## agent-memory (グローバル) との差別化

| 項目 | agent-memory | project-memory |
|------|-------------|----------------|
| スコープ | グローバル (全プロジェクト) | プロジェクト固有 |
| 寿命 | AIユーザーの生涯 | プロジェクトの期間 |
| 保存先 | `.claude/skills/agent-memory/memories/` | `_ai-context/context/memories/` |

## 自律行動パターン

### 先回り保存 (メイン)

以下のような知見を発見したら、確認の上で保存する:

- デバッグで判明した原因と対処法
- 環境構築やセットアップの手順・注意点
- アーキテクチャ上の制約や設計理由
- 外部サービスやAPIの挙動に関する発見
- パフォーマンスチューニングの結果

提案例:
```
📝 この知見をプロジェクトメモリに保存しますか？
→ SQLタイムアウト問題: コネクションプール設定の最適値と根拠
```

### 先回り検索

以下の状況で、関連する既存メモリがないか自動的に検索する:

- 類似の問題に取り組み始めたとき
- 以前扱ったことがありそうな領域に入ったとき
- ユーザーが「前にやったはず」「どうだったっけ」と言ったとき

### 明示的な指示

ユーザーから明示的に指示された場合は、提案ステップを挟まず即座に保存・検索を実行する:
- 保存: 「覚えておいて」「この知見を記録」「メモリに保存して」→ 確認不要、そのまま保存
- 検索: 「前に調べたことは？」「○○について何か残ってる？」→ そのまま検索して結果を返す

## 保存

### 1. フォルダ構成

自由形式。コンテンツに応じてAIが判断。

```
memories/
├── architecture/
│   └── microservices-decision.md
├── debugging/
│   └── sql-timeout-issue.md
└── setup/
    └── environment-config.md
```

### 2. Frontmatter

```yaml
---
summary: "1-2行の説明 - このメモリが何か、重要な問題かTopicか、なぜ重要か"
created: 2026-02-21
project: {ProjectName}
phase: design  # 任意
tags: []       # 任意
---
```

summaryは詳細要不要を判断できるだけの文脈を含めること。

### 3. ファイル構成

```markdown
---
summary: "{1-2行の説明}"
created: YYYY-MM-DD
project: {ProjectName}
---

# {タイトル}

## Context

目標、背景、制約

## State

何が完了しているか、進行中か、ブロックされているか

## Details

重要なファイル、コマンド、コードスニペット

## Next steps

次にするべきこと、未解決の質問
```

## 検索

### ワークフロー

```bash
# 1. 全サマリー表示
rg "^summary:" _ai-context/context/memories/ --no-ignore

# 2. キーワード検索
rg "^summary:.*{keyword}" _ai-context/context/memories/ -i

# 3. タグ検索
rg "^tags:.*{tag}" _ai-context/context/memories/ -i

# 4. フルテキスト検索 (summary検索で不足の場合)
rg "{keyword}" _ai-context/context/memories/ -i

# 5. 該当ファイルを閲覧
```

## メンテナンス

- 更新: 情報が変化したら、内容を更新しfrontmatterに `updated` フィールドを追加
- 削除: 関連性がなくなったメモリは削除
- 統合: 関連するメモリが大きくなったらマージ
- 再編成: 知識ベースが進化したら、より適したカテゴリに移動

## CCL との連携

- memory 保存時: 重要な情報は current_focus.md への更新を提案
- 決定事項を含むmemory: decision_log への記録を提案
- 自動読み込み: セッション開始時の自動読み込みはしない（decision_log, current_focusとは異なる）

## ガイドライン

1. 再開のための記述: メモリは後で作業を再開するために存在。文脈を失わないために必要なすべてのポイントを記録
2. 自己完結的なメモ: 読者が内容を理解し行動するために事前知識が不要な完全な文脈を含める
3. summary判断可能: summaryを読んだだけで詳細が必要かどうか判断できること
4. 最新に保つ: 古くなった情報は更新または削除
5. 実践的に: 実際に役立つものを保存、すべてではない
