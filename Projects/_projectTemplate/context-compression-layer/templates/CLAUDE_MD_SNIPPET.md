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

current_focus.md の末尾「更新」日付が3日以上前の場合、1回だけ聞いてください:
「前回から何か進展や変更はありましたか？（なければそのまま作業に入ります）」
回答があれば current_focus.md に反映してから作業開始。なければそのまま開始。

### AI行動規範（自律的に従うこと）

以下はスキルの明示的な呼び出しを必要としません。AIが自然な判断で実行してください。

#### 意思決定の検出と記録

- 会話中にアーキテクチャや技術選定に関わる決定が出たら、1行で提案する:
  「💡 Decision Logに記録しますか？ → {決定の要約}」
- 承認されたら `_ai-context/context/decision_log/YYYY-MM-DD_topic.md` をTEMPLATEに従い作成
- 1セッション最大3回まで。断られたらそれ以上勧めない

#### セッション終了の検知と記録

- 作業の区切り（「ありがとう」「ここまで」等）を検知したら、AI作業分を current_focus.md に追記提案する
- 既存の内容は触らない。AIが追記する行には [AI] をつける
- 3-5行以内で簡潔に。短い質問応答だけの場合は提案不要

#### Obsidian ナレッジ連携

- 作業中に再利用価値のある知見（デバッグ結果、環境設定、設計理由等）を発見したら、`_ai-context/obsidian_notes/notes/` 等への保存を提案する
- トピックに関連するノートがありそうな場合、`_ai-context/obsidian_notes/` 内を自発的に検索して文脈を補完する
- まとまった作業セッション終了時 -> `obsidian_notes/daily/YYYY-MM-DD_ai-session.md` にセッションサマリーを提案
- 会議内容の共有時 -> `obsidian_notes/meetings/YYYY-MM-DD_{topic}.md` に構造化議事録を提案
- 技術的な発見・設計検討 -> `obsidian_notes/notes/` or `specs/` への記録を提案
- AI生成ノートには frontmatter に `author: ai` と `#ai-memory` タグ（`tags: [ai-memory]`）を含める
- `weekly/` には書き込まない（人間のリフレクション用）
- 1セッション最大2回まで。断られたら勧めない
```

---

## ワークスペース全体の CLAUDE.md に追記（任意）

```markdown
## Context Compression Layer

プロジェクト横断の作業時は `.context/active_projects.md` を確認してください。
各プロジェクト内の指示は、各プロジェクトの CLAUDE.md に記載されています。
```
