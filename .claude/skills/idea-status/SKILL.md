---
name: idea-status
description: アイデアの進捗状況を表示する。引数なしで全アイデアの一覧、引数ありで特定アイデアの詳細を表示する
argument-hint: "[idea-name] [--sort=phase|updated] (省略時は全アイデア一覧・フェーズ順)"
user-invocable: true
---

アイデアの進捗状況を表示する。

## 引数の解釈

`$ARGUMENTS` を以下のように分解し、`IDEA_NAME` と `SORT` の 2 変数に格納してから後段で使用します。raw `$ARGUMENTS` をパスや識別子に直接使わないでください（フラグを含むと path が壊れるため）。

```bash
IDEA_NAME=""
SORT="phase"  # デフォルト: フェーズ番号昇順・同フェーズ内は名前昇順
for token in $ARGUMENTS; do
  case "$token" in
    --sort=phase|--sort=updated)
      SORT="${token#--sort=}"
      ;;
    --*)
      echo "警告: 未知のフラグ: $token" >&2
      ;;
    *)
      IDEA_NAME="$token"
      ;;
  esac
done
```

- `$IDEA_NAME` が空 — 全アイデア一覧（`$SORT` で並び替え）
- `$IDEA_NAME` が非空 — 特定アイデアの詳細（`$SORT` は無視）

## 手順

### `$IDEA_NAME` が空の場合（全アイデア一覧）

1. `ideas/` 配下の全ディレクトリを列挙する（submodule も含む）
2. 各アイデアの `README.md` からステータステーブルを読み取る
3. `$SORT` に基づいてソート基準を適用する:
   - `phase`（デフォルト）: 現在フェーズ番号の昇順 → 名前昇順
   - `updated`: 最終更新日の降順（新しい順）
4. 以下の形式で一覧を表示する:

```
| アイデア | 現在のフェーズ | ステータス記号 | 最終更新 |
|---------|--------------|---------------|---------|
| <name> | <phase> | 🔄 / ✅ / 🔁 / ❌ など | <date> |
```

5. アイデアが存在しない場合は `/new-idea` の使い方を案内する

### `$IDEA_NAME` が非空の場合（特定アイデア）

1. `ideas/$IDEA_NAME/README.md` を読む
2. 全フェーズのステータスを表示する
3. 現在進行中のフェーズについて:
   - そのフェーズのドキュメントの作成状況を確認する（Phase 4 は `04-behavior/` 配下、レガシー形式では `04-requirements.md`）
   - 次にやるべきことを提案する
4. 存在しないアイデア名が指定された場合は、利用可能なアイデア一覧を表示する
