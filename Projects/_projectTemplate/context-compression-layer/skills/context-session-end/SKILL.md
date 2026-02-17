---
name: context-session-end
description: At natural breakpoints in the work, such as "Thank you," "That's all for now," or "Finished," the AI proposes appending its contributions to `current_focus.md`. It only appends the AI's work, without overwriting human records.
---

# Context Session End

作業の区切りで、AIが関与した分だけ current_focus.md に追記提案するスキル。

## トリガー

明示的コマンド不要。以下の自然な区切りで発動:

- 「ありがとう」「助かった」
- 「一旦ここまで」「今日はこれで」
- まとまった作業（複数ステップ）が一段落したとき

**発動しない**: 短い質問応答（「このSQL正しい？」→「OK」）程度の場合。

## 手順

### 1. AI作業分の要約

セッション中にAIが関与した作業を振り返り、以下を抽出:

- やったこと（コード作成、設計レビュー等）
- 決まったこと（あれば）
- 残っていること

### 2. 追記案の提示

```
📝 current_focus.md に追記しますか？

【最近あったこと】に追加:
  + [AI] CRUD API 5本作成完了
  + [AI] SQLインデックス追加

【次やること】に追加:
  + E2Eテスト作成

（はい / 修正あり / 不要）
```

### 3. Decision Log 提案（該当する場合のみ）

重要な決定があった場合のみ、1行で:

```
💡 「ページネーションをcursor方式に決定」→ Decision Logに記録しますか？
```

承認されたら `context-decision-log` スキルに委譲。

### 4. 更新実行

承認後:
- current_focus.md の該当セクションに追記（既存内容は触らない）
- `[AI]` プレフィックスをつける
- 末尾の「更新」日付を更新

## ルール

- ✅ AI作業分のみ追記提案する
- ✅ 既存の人間が書いた行はそのまま残す
- ✅ `[AI]` プレフィックスで区別する
- ✅ 3-5行以内で簡潔に
- ❌ 人間が書いた行を編集・削除しない
- ❌ current_focus.md を全面書き換えしない
- ❌ 承認なしにファイルを更新しない
