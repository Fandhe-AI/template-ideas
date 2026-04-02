# Ideas

アイデアのブレインストーミングから要件定義・タスク分解・ロードマップ作成までを Claude Code で体系的に管理するリポジトリ。

6つのフェーズと判定ゲートで構成されたワークフローにより、アイデアの発想から実装着手までを段階的に進めます。

**Author:** Fandhe Inc.

## クイックスタート

### 必要なもの

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

### セットアップ

```sh
# リポジトリをクローン
git clone <repository-url>
cd ideas

# Claude Code を起動
claude
```

### 新しいアイデアを始める

```
/new-idea my-awesome-tool
```

ディレクトリ作成からブレインストーミング開始まで自動で進行します。

## ワークフロー

アイデアは6フェーズを順に進行します。フェーズ間には判定ゲートがあり、適切なタイミングで Go/No-Go を判断します。

```text
Phase 1: ブレスト        → アイデアの発散・要件概要の固め
  ↓ [追求判定]
Phase 2: PoC計画         → 検証すべき項目の洗い出し
  ↓
Phase 3: PoC実施         → 各検証項目の実施と結果記録
  ↓ [Go/No-Go判定] ← 最重要ゲート
Phase 4: 要件定義        → PoC結果を踏まえた詳細要件
  ↓ [スコープ確認]
Phase 5: タスク分解      → 要件ごとの具体タスク・工数見積もり
  ↓
Phase 6: ロードマップ    → マイルストーンとスケジュール
  ↓ [着手判定]
```

フェーズは逆戻り可能です。PoC 失敗時のアプローチ見直しや、要件定義中の追加 PoC など、柔軟にフィードバックループを回せます。

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
  04-requirements.md        — 要件定義テンプレート
  05-tasks.md               — タスク分解テンプレート
  06-roadmap.md             — ロードマップテンプレート
ideas/
  <idea-name>/              — 各アイデア（kebab-case）
    README.md               — ステータス＋概要
    01-brainstorm.md        — Phase 1
    02-poc-plan.md          — Phase 2
    03-poc/                 — Phase 3（PoC 項目ごとにサブディレクトリ）
    04-requirements.md      — Phase 4
    05-tasks.md             — Phase 5
    06-roadmap.md           — Phase 6
```

## Claude Code での開発

### スキル

| コマンド | 説明 |
| --- | --- |
| `/new-idea <name>` | 新しいアイデアのディレクトリを作成し、ブレインストーミングを開始 |
| `/advance-phase <idea-name>` | 現在のフェーズを完了し、次のフェーズに進む |
| `/idea-status [idea-name]` | アイデアの進捗状況を表示（引数なしで全一覧） |
| `/idea-summary <idea-name>` | 全フェーズドキュメントから包括的なサマリーを生成 |

### エージェント

各フェーズに特化した5つのカスタムエージェントが `.claude/agents/` に定義されています:

| エージェント | 役割 |
| --- | --- |
| `brainstorm` | アイデアの発散・課題の深掘り・要件概要の整理 |
| `poc-planner` | 技術的リスクの特定・PoC 項目の洗い出し・検証計画の策定 |
| `requirements` | PoC 結果の分析・機能/非機能要件の整理・MoSCoW 分類 |
| `task-decomposer` | 要件のタスク分解・工数見積もり・依存関係の整理 |
| `roadmap` | マイルストーン設計・タイムライン策定・リスク管理 |

### ワークフロー

スキルとエージェントを組み合わせた開発フローが用意されています:

```text
/new-idea → ブレスト → /advance-phase → PoC計画 → PoC実施
  → /advance-phase → 要件定義 → /advance-phase → タスク分解
  → /advance-phase → ロードマップ → 実装着手
```

`/advance-phase` は判定ゲートの確認、ステータス更新、次フェーズのエージェント起動を自動で行います。

## 詳細ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [はじめに](docs/guide/getting-started.md) | リポジトリの使い方・基本操作 |
| [ワークフロー全体像](docs/guide/workflow-overview.md) | 6フェーズ＋判定ゲートの全体像 |
| [各フェーズの詳細ガイド](docs/guide/phase-guide.md) | フェーズごとの目的・ゴール・進め方・完了条件 |
| [ベストプラクティス](docs/guide/best-practices.md) | 壁打ちのコツ・PoC 設計の勘所・要件定義のポイント |
| [注意点・よくある失敗](docs/guide/tips-and-pitfalls.md) | スコープ肥大化・PoC 不足・見積もりの甘さなど |
| [Claude Code 活用法](docs/guide/claude-code-usage.md) | エージェント・スキルの使い分け・プロンプトの書き方 |

## Author

Fandhe Inc.
