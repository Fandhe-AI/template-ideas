# Ideas

アイデアのブレインストーミングからビヘイビア定義・タスク分解・ロードマップ作成までを Claude Code で体系的に管理するリポジトリ。

6つのフェーズと判定ゲートで構成されたワークフローにより、アイデアの発想から実装着手までを段階的に進めます。

**Author:** Fandhe Inc.

## クイックスタート

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) を用意する
2. このリポジトリをクローンして、ルートで `claude` を起動する
3. `/new-idea <idea-name>` で最初のアイデアを開始する

詳しいセットアップ手順は [`docs/guide/getting-started.md`](docs/guide/getting-started.md) を参照してください。

## ワークフロー

アイデアは6フェーズを順に進行します。フェーズ間には判定ゲートがあり、適切なタイミングで Go/No-Go を判断します。

```text
Phase 1: ブレスト        → アイデアの発散・要件概要の固め
  ↓ [追求判定]
Phase 2: PoC計画         → 検証すべき項目の洗い出し
  ↓
Phase 3: PoC実施         → 各検証項目の実施と結果記録
  ↓ [Go/No-Go判定] ← 最重要ゲート
Phase 4: ビヘイビア定義  → PoC結果を踏まえた画面・API ごとのビヘイビア（SSOT）
  ↓ [スコープ確認]
Phase 5: タスク分解      → ビヘイビアごとの具体タスク・工数見積もり
  ↓
Phase 6: ロードマップ    → マイルストーンとスケジュール
  ↓ [着手判定]
```

フェーズは逆戻り可能です。PoC 失敗時のアプローチ見直しや、ビヘイビア定義中の追加 PoC など、柔軟にフィードバックループを回せます。

Phase 4 のビヘイビアは振る舞いの唯一の正（Single Source of Truth）です。仕様変更はまず `04-behavior/` を変更し、タスクと仕様書（`spec.md`、`/generate-spec` で自動生成）を追随させます。

## プロジェクト構成

```text
docs/
  guide/
    getting-started.md      — はじめに：使い方ガイド
    workflow-overview.md    — ワークフロー全体像と進め方
    phase-guide.md          — 各フェーズの詳細ガイド
    best-practices.md       — ベストプラクティス集
    tips-and-pitfalls.md    — 気をつけるポイント・よくある失敗
    claude-code-usage.md    — Claude Code の効果的な活用法
_templates/
  01-brainstorm.md          — ブレインストーミングテンプレート
  02-poc-plan.md            — PoC 計画テンプレート
  03-poc-result.md          — PoC 結果テンプレート
  04-behavior/              — ビヘイビア定義テンプレート（README / screen / api / topic）
  05-tasks.md               — タスク分解テンプレート
  06-roadmap.md             — ロードマップテンプレート
ideas/
  <idea-name>/              — 各アイデア（kebab-case）
    README.md               — ステータス＋概要
    01-brainstorm.md        — Phase 1
    02-poc-plan.md          — Phase 2
    03-poc/                 — Phase 3（PoC 項目ごとにサブディレクトリ）
    04-behavior/            — Phase 4（画面・API ごとのビヘイビア。既存アイデアは 04-requirements.md）
    05-tasks.md             — Phase 5
    06-roadmap.md           — Phase 6
    spec.md                 — 仕様書（/generate-spec で 04-behavior/ から自動生成）
```

## Claude Code での開発

### スキル

| コマンド | 説明 |
| --- | --- |
| `/new-idea <name>` | 新しいアイデアのディレクトリを作成し、ブレインストーミングを開始 |
| `/advance-phase <idea-name>` | 現在のフェーズを完了し、次のフェーズに進む |
| `/idea-status [idea-name]` | アイデアの進捗状況を表示（引数なしで全一覧） |
| `/idea-summary <idea-name>` | 全フェーズドキュメントから包括的なサマリーを生成 |
| `/generate-spec <idea-name>` | `04-behavior/` から人間・クライアント向け仕様書 `spec.md` を自動生成 |

### エージェント

各フェーズに特化した5つのカスタムエージェントが `.claude/agents/` に定義されています:

| エージェント | 役割 |
| --- | --- |
| `brainstorm` | アイデアの発散・課題の深掘り・要件概要の整理 |
| `poc-planner` | 技術的リスクの特定・PoC 項目の洗い出し・検証計画の策定 |
| `behavior` | PoC 結果の分析・画面/API ごとのビヘイビア定義・優先度／ステータス付与 |
| `task-decomposer` | ビヘイビアのタスク分解・工数見積もり・依存関係の整理 |
| `roadmap` | マイルストーン設計・タイムライン策定・リスク管理 |

### ワークフロー

スキルとエージェントを組み合わせた開発フローが用意されています:

```text
/new-idea → ブレスト → /advance-phase → PoC計画 → PoC実施
  → /advance-phase → ビヘイビア定義 → /generate-spec → /advance-phase → タスク分解
  → /advance-phase → ロードマップ → 実装着手
```

`/advance-phase` は判定ゲートの確認、ステータス更新、次フェーズのエージェント起動を自動で行います。

## Fandhe-AI エコシステム

本リポジトリの `.agents/skills/` 配下のスキルは [Fandhe-AI/agent-cli-skills](https://github.com/Fandhe-AI/agent-cli-skills) を upstream とし、ルート直下の `skills-lock.json` で出所と SHA256 を記録しています。

スキルを改修したら `/contribute-skill <skill-name>` で upstream へ PR を投げ、マージ後に `/sync-skills-lock` でハッシュを同期します。新しい upstream スキルを取り込むには `npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>` を実行します。sandbox 環境での GitHub 操作は [`docs/sandbox-tls.md`](docs/sandbox-tls.md) を、詳しい流れは [スキル開発ガイド](docs/guide/skill-development.md) を参照してください。

## 詳細ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [ガイド総合目次](docs/guide/index.md) | 読者別の推奨ルート・ナビゲーション |
| [はじめに](docs/guide/getting-started.md) | リポジトリの使い方・基本操作 |
| [ワークフロー全体像](docs/guide/workflow-overview.md) | 6フェーズ＋判定ゲートの全体像 |
| [各フェーズの詳細ガイド](docs/guide/phase-guide.md) | フェーズごとの目的・ゴール・進め方・完了条件 |
| [ベストプラクティス](docs/guide/best-practices.md) | 壁打ちのコツ・PoC 設計の勘所・要件定義のポイント |
| [注意点・よくある失敗](docs/guide/tips-and-pitfalls.md) | スコープ肥大化・PoC 不足・見積もりの甘さなど |
| [Claude Code 活用法](docs/guide/claude-code-usage.md) | エージェント・スキルの使い分け・プロンプトの書き方 |
| [スキル開発ガイド](docs/guide/skill-development.md) | ローカルスキル vs upstream、`skills-lock.json`、貢献フロー |

## Author

Fandhe Inc.
