# CLAUDE.md 追記スニペット

以下を既存のCLAUDE.mdに追記してください。

---

## プロジェクト個別の CLAUDE.md に追記

```markdown
## Context Compression Layer

### Context Loading Priority

AIはセッション開始時、以下の順序でコンテキストを読み込んでください:

1. [必須] current_focus.md (目安: 500 tokens / 約400文字以内)
2. [必須] project_summary.md (目安: 300 tokens / 約250文字以内)
3. [状況依存] decision_log/ の最新3件
4. [オンデマンド] file_map.md (ファイル構造の質問時のみ)
5. [オンデマンド] obsidian_notes/ (質問に関連するものだけ検索)

ファイルが目安サイズを超えていたら整理を提案してください:
「current_focus.md が大きくなっています。古い情報を focus_history/ にアーカイブして整理しますか？」

### Session Start Protocol

AIはセッション開始時（最初のユーザーメッセージに応答する前）に以下を実行:

1. _ai-context/context/current_focus.md を読む
2. _ai-context/context/project_summary.md を読む
3. _ai-context/context/decision_log/ の最新3件を確認する
4. 未完了・保留事項があれば、以下の形式で1〜2行のサマリーを提示する:
   「前回は [作業内容] を行いました。[未完了事項] が保留中です。」
5. 更新日付が3日以上前の場合のみ、1回だけ確認する:
   「前回から進展や変更はありましたか？（なければそのまま作業に入ります）」
6. ユーザーの指示を待つ（自発的に作業を開始しない）

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

- 1セッション最大2回まで。断られたら勧めない
```

---

## ワークスペース全体の CLAUDE.md に追記（任意）

```markdown
## Context Compression Layer

プロジェクト横断の作業時は `.context/active_projects.md` を確認してください。
各プロジェクト内の指示は、各プロジェクトの CLAUDE.md に記載されています。
```
