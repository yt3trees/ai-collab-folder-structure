# Global AI Context Hub

プロジェクト横断のナレッジを蓄積するハブ。特定プロジェクトに依存しない再利用可能な知見を保管する。

## 構成

- tech-patterns/: 複数プロジェクトで再利用できるコード・設計パターン
- lessons-learned/: 失敗・ハマりから学んだこと

## アクセスパス

- 絶対パス: `%USERPROFILE%\Box\Obsidian-Vault\ai-context\`
- プロジェクトからの相対参照: `_ai-context/obsidian_notes/../../ai-context/`
  (obsidian_notes/ junction が Box/Obsidian-Vault/Projects/<project>/ を指すため、../../ で Vault ルートに遡れる)

## 保存ルール

- frontmatter に `project:` タグでどのプロジェクト由来かを記録する
- AI生成ノートには `author: ai` と `tags: [ai-memory]` を付与する

## 保存提案形式 (AI向け)

```
📓 グローバルナレッジに記録しますか？
→ ai-context/tech-patterns/{filename}.md
  {内容の1行サマリー}
```
