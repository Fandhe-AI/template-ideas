---
name: idea-summary
description: 指定したアイデアの全フェーズドキュメントを読み込み、包括的なサマリーを生成する
argument-hint: "<idea-name> (例: ai-code-review-tool)"
user-invocable: true
---

アイデア `$ARGUMENTS` の全体サマリーを生成する。

## 手順

1. `ideas/$ARGUMENTS/` 配下の全ドキュメントを読み込む
   - README.md, 01-brainstorm.md, 02-poc-plan.md, 03-poc/**/README.md, 04-requirements.md, 05-tasks.md, 06-roadmap.md
   - 存在するファイルのみ読み込む

2. 以下の構造でサマリーを出力する:

### 現在のステータス
- 現在のフェーズと進捗

### アイデア概要
- 背景と課題
- 提案する解決策

### PoC結果サマリー（Phase 3 以降の場合）
- 検証した項目と結果
- 主要な知見

### 要件サマリー（Phase 4 以降の場合）
- Must要件の一覧
- 主要な非機能要件

### 実装計画サマリー（Phase 5 以降の場合）
- タスク総数と推定工数
- 主要マイルストーン

### リスクと課題
- 未解決の課題
- 主要リスク

3. サマリーはユーザーに表示する（ファイルには書き込まない）
4. 引数が空の場合はユーザーにアイデア名を聞く
