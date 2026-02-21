# CLAUDE.md 追記スニペット

以下を既存のCLAUDE.mdに追記してください。

---

## プロジェクト個別の CLAUDE.md に追記

```markdown
## Context Compression Layer

### 初回読み込み（自動）

このプロジェクトで最初のタスクに取りかかる前に、以下を読んでください:

1. `_ai-context/context/project_summary.md` - プロジェクト全体像
2. `_ai-context/context/current_focus.md` - 現在のフォーカス
3. `_ai-context/context/decision_log/` の最新3件（日付降順）

current_focus.md の末尾「更新」日付が3日以上前の場合、1回だけ聞いてください:
「前回から何か進展や変更はありましたか？（なければそのまま作業に入ります）」
回答があれば current_focus.md に反映してから作業開始。なければそのまま開始。

### 作業中

重要な意思決定（技術選定、設計判断、方針変更）があったら、1行で提案してください:
「💡 Decision Logに記録しますか？ → {決定の要約}」
承認されたら `_ai-context/context/decision_log/YYYY-MM-DD_topic.md` をTEMPLATEに従い作成。
1セッションで最大3回まで。断られたらそれ以上勧めない。

### 作業の区切り

まとまった作業が一段落したら、AI作業分を current_focus.md に追記提案してください:
- 既存の内容は触らない
- AIが追記する行には [AI] をつける
- 3-5行以内で簡潔に
- 短い質問応答だけの場合は提案不要

### Project Memory

価値のある知見を発見したら、`_ai-context/context/memories/` に保存してください:
- 「覚えておいて」「この知見を記録」などのトリガー
- 先回りして保存も推奨
- 検索: `rg "^summary:" _ai-context/context/memories/`
```

---

## ワークスペース全体の CLAUDE.md に追記（任意）

```markdown
## Context Compression Layer

プロジェクト横断の作業時は `.context/active_projects.md` を確認してください。
各プロジェクト内の指示は、各プロジェクトの CLAUDE.md に記載されています。
```
