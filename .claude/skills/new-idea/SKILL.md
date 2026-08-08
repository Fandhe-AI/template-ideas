---
name: new-idea
description: 新しいアイデアのディレクトリ構造を作成し、ブレインストーミングを開始する
argument-hint: "<idea-name> (kebab-case, 例: ai-code-review-tool)"
user-invocable: true
---

新しいアイデア `$ARGUMENTS` のディレクトリ構造を作成し、ブレインストーミングを開始する。

## 手順

1. アイデア名を検証する
   - kebab-case であること（英数字とハイフンのみ）
   - `ideas/$ARGUMENTS/` がまだ存在しないこと
   - 引数が空の場合はユーザーに名前を聞く

2. ディレクトリ構造を作成する:
   ```
   ideas/$ARGUMENTS/
   ├── README.md
   └── 03-poc/.gitkeep
   ```

3. `README.md` を以下の内容で作成する:
   ```markdown
   # $ARGUMENTS

   ## ステータス

   | フェーズ | 状態 | 更新日 |
   |---------|------|--------|
   | 1. ブレスト | 🔄 進行中 | <今日の日付> |
   | 2. PoC計画 | ⬜ 未着手 | - |
   | 3. PoC実施 | ⬜ 未着手 | - |
   | 4. ビヘイビア定義 | ⬜ 未着手 | - |
   | 5. タスク分解 | ⬜ 未着手 | - |
   | 6. ロードマップ | ⬜ 未着手 | - |

   ## 概要
   <!-- 一言で説明 -->

   ## ドキュメント
   - [ブレインストーミング](./01-brainstorm.md)
   ```

4. ユーザーにディレクトリが作成されたことを伝え、ブレインストーミングを開始する
   - `_templates/01-brainstorm.md` のテンプレートを参照しながら進める
   - まずユーザーにアイデアの背景やきっかけを聞く

## オプション: submodule 化

将来、アイデアが独立リポジトリ化すべき規模に育った場合（例: `ideas/team-hub/`、`ideas/automation/` パターン）、以下の流れでサブモジュール化できる。

1. 別リポジトリ（例: `Fandhe-AI/<idea-name>-spec`）を作成
2. 既存の `ideas/$ARGUMENTS/` 配下を新リポジトリへ移設
3. ローカルで `git submodule add git@github.com:Fandhe-AI/<idea-name>-spec.git ideas/$ARGUMENTS`
4. `.gitmodules` に登録されたことを確認

submodule 化の判断は Phase 6 の「着手判定」時、もしくはドキュメント量が大規模化したタイミングでユーザーと相談する。
