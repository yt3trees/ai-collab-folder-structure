# CLAUDE.md 追記スニペット

以下を既存のCLAUDE.mdに追記してください。

---

## プロジェクト個別の CLAUDE.md に追記

```markdown
## Context Compression Layer

### Session Start Protocol

セッション開始時（最初のユーザーメッセージへの応答前）に実行:

1. `_ai-context/context/current_focus.md` を読む（目安 ~500 tokens）
2. `_ai-context/context/project_summary.md` を読む（目安 ~300 tokens）
3. `_ai-context/context/tensions.md` を読む（未解決課題の把握）
4. `_ai-context/context/decision_log/` の最新3件を確認する
5. `file_map.md`・`obsidian_notes/` はオンデマンドのみ
6. 未完了事項を1〜2行でサマリー提示する
7. 更新が3日以上前なら進捗を1回確認する
8. ユーザーの指示を待つ

目安サイズ超過時は `focus_history/` へのアーカイブを提案する。

### AI行動規範

| 区分 | 対象 | 動作 |
|-----|------|------|
| Auto | current_focus.md 追記 | 承認なし |
| Notify | tensions.md・decision_log (低影響) | 1行報告後に実行 |
| Confirm | project_summary.md・decision_log (高影響) | 確認を取る |

#### 未解決課題
トレードオフ・懸念を検出 → 「⚠️ tensions.md に記録しますか？ → {要約}」
解決時は削除を提案し decision_log への昇格を促す。最大2回/セッション。

#### 意思決定
アーキテクチャ・技術選定の決定を検出 → 「💡 Decision Logに記録しますか？ → {要約}」
承認後 `decision_log/YYYY-MM-DD_topic.md` を作成。最大3回/セッション。

#### セッション終了
「ありがとう」「ここまで」等で current_focus.md への追記を提案。
`[AI]` プレフィックス・3〜5行・既存行は変更しない。

#### Obsidian連携
- 再利用価値のある知見は `obsidian_notes/notes/` 等への保存を提案
- 関連ノートがありそうなら `obsidian_notes/` を検索して文脈補完
- セッション終了時 → `daily/YYYY-MM-DD_ai-session.md` 提案
- 会議内容共有時 → `meetings/YYYY-MM-DD_{topic}.md` 提案
- AI生成ノートに `author: ai`・`tags: [ai-memory]` 付与
最大2回/セッション。断られたら勧めない。
```

---

## ワークスペース全体の CLAUDE.md に追記（任意）

```markdown
## Context Compression Layer

プロジェクト横断の作業時は `.context/active_projects.md` を確認してください。
各プロジェクト内の指示は、各プロジェクトの CLAUDE.md に記載されています。
```
