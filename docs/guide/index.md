# ガイド総合目次

Ideas Repository の使い方を読者別に案内するナビゲーションマップです。目的に応じて推奨ルートを選んでください。

## 読者別推奨ルート

### はじめてリポジトリを使う方

1. [はじめに](./getting-started.md) — セットアップと基本操作
2. [ワークフロー全体像](./workflow-overview.md) — 6 フェーズと判定ゲートの概念
3. [各フェーズの詳細ガイド](./phase-guide.md) — 各フェーズの目的・進め方・完了条件
4. `/new-idea <name>` で最初のアイデアを始める

### 実践的にアイデアを回す方

1. [各フェーズの詳細ガイド](./phase-guide.md) — フェーズ単位での進め方
2. [ベストプラクティス](./best-practices.md) — 壁打ち・PoC 設計・ビヘイビア定義の勘所
3. [気をつけるポイント・よくある失敗](./tips-and-pitfalls.md) — スコープ肥大化・PoC 不足への対処

### Claude Code をより深く使う方

1. [Claude Code 活用法](./claude-code-usage.md) — エージェント・スキルの使い分け、プロンプトの書き方
2. [スキル開発ガイド](./skill-development.md) — ローカルスキル vs upstream、`skills-lock.json`、上流貢献フロー

### メンテナー・貢献者の方

1. [スキル開発ガイド](./skill-development.md) — 上流貢献フロー、`/contribute-skill` / `/sync-skills-lock` の使い方、新 upstream スキルの取り込み手順
2. `../../.claude/rules/` — 日本語規約・フェーズ遷移ルール・Conventional Commits の共通規約
3. [`../../CLAUDE.md`](../../CLAUDE.md) — Claude Code への指令書

## ドキュメント一覧

| ドキュメント | 対象読者 | 内容 |
|------------|---------|------|
| [はじめに](./getting-started.md) | 全員 | セットアップ・基本操作 |
| [ワークフロー全体像](./workflow-overview.md) | 全員 | 6 フェーズ＋判定ゲートの概念 |
| [各フェーズの詳細ガイド](./phase-guide.md) | 実践者 | フェーズ単位の目的・ゴール・完了条件 |
| [ベストプラクティス](./best-practices.md) | 実践者 | 進め方のコツ・落とし穴回避 |
| [気をつけるポイント](./tips-and-pitfalls.md) | 実践者 | スコープ・PoC・見積もりの落とし穴 |
| [Claude Code 活用法](./claude-code-usage.md) | 応用者 | エージェント・スキル・プロンプト |
| [スキル開発ガイド](./skill-development.md) | 応用者・貢献者 | `skills-lock.json` と上流貢献フロー |

## リポジトリ構造ドキュメント

- [`../../README.md`](../../README.md) — リポジトリのトップページ
- [`../../CLAUDE.md`](../../CLAUDE.md) — Claude Code への指令書（自動読込）
- [`../../.claude/rules/`](../../.claude/rules/) — Claude エージェント・スキル共通ルール

## 関連

- [Fandhe-AI/agent-cli-skills](https://github.com/Fandhe-AI/agent-cli-skills) — 上流スキルリポジトリ（`skills-lock.json` の参照先）
