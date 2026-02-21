---
name: project-memory
description: Record and retrieve project-specific memory. Triggers: 'Remember this' 'Record this insight' 'What I looked up before' Proactively save valuable insights discovered by AI, and proactively search for them.
---

# Project Memory

プロジェクト固有のメモリ。AIが作業中に発見した知見を記録・検索する。

**保存先:** `_ai-context/context/memories/`

## agent-memory (グローバル) との差別化

| 項目 | agent-memory | project-memory |
|------|-------------|----------------|
| スコープ | グローバル (全プロジェクト) | プロジェクト固有 |
| 寿命 | AIユーザーの生涯 | プロジェクトの期間 |
| 保存先 | `.claude/skills/agent-memory/memories/` | `_ai-context/context/memories/` |

## トリガー

- 明示的コマンド: 「覚えておいて」「この知見を記録」「前に調べたことは」
- 先回り: AIが発見した価値のある知見を保存
- 検索: 作業開始前に関連内容を検索

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

**重要:** summaryは詳細要不要を判断できるだけの上下文を含めること。

### 3. ファイル作成

```bash
mkdir -p "_ai-context/context/memories/{category}/"
cat > "_ai-context/context/memories/{category}/{filename}.md" << 'EOF'
---
summary: "{1-2行の説明}"
created: $(date +%Y-%m-%d)
project: {ProjectName}
phase: {任意}
tags: []
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
EOF
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

# 5. 該当する場合は該当日記憶ファイルを閲覧
```

## メンテナンス

- **更新**: 情報が変化したら、内容を更新しfrontmatterに `updated` フィールドを追加
- **削除**: 関連性がなくなったメモリは削除
- **統合**: 関連するメモリが大きくなったらマージ
- **再編成**: 知識ベースが進化したら、より適したカテゴリに移動

## CCL との連携

- **memory 保存時**: 重要な情報は current_focus.md への更新を提案
- **決定事項を含むmemory**: decision_log への記録を提案
- **自動読み込み**: セッション開始時の自動読み込みはしない（decision_log, current_focusとは異なります）

## ガイドライン

1. **再開のための記述**: メモリは後で作業を再開するために存在。文脈を失わないために必要なすべてのポイントを記録 - 決定事項、理由、現在の状態、次のステップ
2. **自己完結的なメモ**: 読者が内容を理解和行動するために事前の知識が不要になるような完全な文脈を含める
3. **-summary 判断可能**: summaryを読んだだけで詳細が必要かどうか判断できること
4. **最新に保つ**: 古くなった情報は更新または削除
5. **実践的に**: 実際に役立つものを保存、すべてではない
