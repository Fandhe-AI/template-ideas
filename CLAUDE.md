# Ideas Repository

> このファイルは Claude Code 用の指令書です。Claude Code 起動時に自動で読み込まれます。ヒューマンリーダブルな入り口は [`README.md`](./README.md) と [`docs/guide/index.md`](./docs/guide/index.md) を参照してください。

アイデアのブレインストーミングからビヘイビア定義・タスク分解・ロードマップ作成までを Claude Code で体系的に管理するリポジトリ。

## ワークフロー

アイデアは以下の6フェーズを順に進行する。フェーズ間には判定ゲートがある。

| フェーズ | ファイル | 内容 |
|---------|---------|------|
| 1. ブレスト | `01-brainstorm.md` | アイデアの発散・要件概要の固め |
| 2. PoC計画 | `02-poc-plan.md` | 検証すべき項目の洗い出し |
| 3. PoC実施 | `03-poc/` | 各PoC項目の検証と結果記録 |
| 4. ビヘイビア定義 | `04-behavior/` | PoC結果を踏まえた画面・API ごとの検証可能なビヘイビア（SSOT） |
| 5. タスク分解 | `05-tasks.md` | ビヘイビアを満たす具体的タスク（`TASK-N`＋対象ビヘイビア） |
| 6. ロードマップ | `06-roadmap.md` | マイルストーンとスケジュール |

Phase 4 のビヘイビアが振る舞いの唯一の正（SSOT）。仕様変更はまず `04-behavior/` を変更し、タスク・仕様書（`spec.md`、`/generate-spec` で自動生成）を追随させる。既存アイデアの `04-requirements.md` はレガシー形式として存置（[`rules/phase-gate.md`](./.claude/rules/phase-gate.md) の形式判定を参照）。

### 判定ゲート

- Phase 1→2: 追求判定（PoCの価値があるか）
- Phase 3→4: Go/No-Go判定（最重要）
- Phase 4→5: スコープ確認
- Phase 6完了: 着手判定

### フィードバックループ

フェーズは逆戻り可能。README.md のステータスで「🔁 再検討中」を使用する。詳細は [`.claude/rules/phase-gate.md`](./.claude/rules/phase-gate.md) を参照。

## ディレクトリ構造

```
ideas/
├── docs/
│   └── guide/            # 使い方ガイド（index.md が目次）
├── _templates/           # フェーズテンプレート (01〜06, 07 は任意)
├── ideas/<name>/         # 各アイデア（kebab-case）
├── .agents/skills/       # upstream 由来の汎用スキル (skills-lock.json で同期)
└── .claude/
    ├── agents/           # カテゴリ別カスタムエージェント (9 個)
    │   ├── phase/        # フェーズ別ビルダー (brainstorm / poc-planner / behavior / task-decomposer / roadmap)
    │   ├── research/     # 調査系 (reference-researcher / sub-investigator)
    │   └── quality/      # 品質系 (doc-reviewer / gate-checker)
    ├── rules/            # 共通ルール (japanese / phase-gate / convention / delegation / delegation-impl / document-quality)
    ├── skills/           # ワークフロースキル (5 個) + upstream への symlink
    └── workflows/        # implement-issue-tree.js (.agents/skills/ への相対 symlink)
```

## 規約

詳細は [`.claude/rules/`](./.claude/rules/) を参照。

- アイデア名: kebab-case（例: `ai-code-review-tool`）
- ドキュメント: 日本語・ですます調で記述（[`rules/japanese.md`](./.claude/rules/japanese.md)）
- 各フェーズのドキュメントは `_templates/` のテンプレートに従う
- README.md の status フィールドを常に最新に保つ
- git commit は各フェーズの区切りで行う（Conventional Commits: [`rules/convention.md`](./.claude/rules/convention.md)）
- フェーズ遷移は [`rules/phase-gate.md`](./.claude/rules/phase-gate.md) に従う
- フェーズ作業は対象パスから委譲先を判断し各エージェントへ委譲する（[`rules/delegation.md`](./.claude/rules/delegation.md) / [`rules/delegation-impl.md`](./.claude/rules/delegation-impl.md)）
- フェーズ文書はトレーサビリティ・テンプレ準拠・ビヘイビアのテスト可能性を満たす（[`rules/document-quality.md`](./.claude/rules/document-quality.md)）

## 委譲方針

main（Claude Code 本体）はフェーズ作業を抱え込まず、対象パスから委譲先エージェントを判断して委譲する。これにより main のコンテキスト消費を抑え、各フェーズに最適化された model で処理する。詳細は [`rules/delegation.md`](./.claude/rules/delegation.md)（調査・設計）・[`rules/delegation-impl.md`](./.claude/rules/delegation-impl.md)（作成・編集）を参照。

### パスベース切り替え表

| 対象パス | 委譲先 | model |
|---------|--------|-------|
| `ideas/<name>/01-brainstorm.md` | `brainstorm` | opus |
| `ideas/<name>/02-poc-plan.md` | `poc-planner` | opus |
| `ideas/<name>/03-poc/<item>/` | `sub-investigator`（検証）/ `poc-planner`（計画修正） | sonnet / opus |
| `ideas/<name>/04-behavior/`（レガシー: `04-requirements.md`） | `behavior` | sonnet |
| `ideas/<name>/05-tasks.md` | `task-decomposer` | sonnet |
| `ideas/<name>/06-roadmap.md` | `roadmap` | sonnet |
| 外部サービス・市場・技術仕様の調査 | `reference-researcher` | sonnet |
| フェーズ文書の品質レビュー | `doc-reviewer` | sonnet |
| 完了条件・判定ゲートの機械チェック | `gate-checker` | haiku |

### model 配分

| 用途 | model |
|------|-------|
| 発散・不確実性評価・PoC 計画（長文脈・WebSearch 併用） | opus |
| ビヘイビア・タスク・ロードマップの構造化／外部調査／品質レビュー | sonnet |
| 機械的チェック（判定ゲート・完了条件）・ドキュメント更新 | haiku |

### main が直接行う作業（委譲しない）

- README.md のステータス更新・判定ゲートの「判定」節記録
- git コミット・PR 作成（`create-commit` / `create-pr` スキル）
- 進捗確認（`/idea-status` / `/idea-summary`）
- 仕様書の自動生成（`/generate-spec`）

## エージェント

`.claude/agents/<category>/` 配下にカテゴリ分割。model はタスク特性に基づいて割り当てている。各エージェントは担当範囲・非対象・編集原則・委譲入力・完了報告・参照ルールを備える（team-hub 構成を参考に詳細化）。

### phase（フェーズ別ビルダー）

| エージェント | model | 役割 |
|-------------|-------|------|
| `brainstorm` | opus | Phase 1: ブレインストーミングの促進（長文脈・WebSearch 併用） |
| `poc-planner` | opus | Phase 2: PoC 項目の特定と計画（不確実性評価・調査） |
| `behavior` | sonnet | Phase 4: ビヘイビアの定義（分割設計・ID 採番・優先度／ステータス） |
| `task-decomposer` | sonnet | Phase 5: タスクの分解と見積もり（構造化・依存関係） |
| `roadmap` | sonnet | Phase 6: ロードマップの構築（マイルストーン・タイムライン） |

### research（調査系）

| エージェント | model | 役割 |
|-------------|-------|------|
| `reference-researcher` | sonnet | 外部サービス・市場・技術仕様・競合の調査（出典付き要約） |
| `sub-investigator` | sonnet | Phase 3 の技術検証・汎用調査・問題調査・データ取得 |

### quality（品質系）

| エージェント | model | 役割 |
|-------------|-------|------|
| `doc-reviewer` | sonnet | フェーズ文書の整合性・テンプレ準拠・トレーサビリティの読取専用レビュー |
| `gate-checker` | haiku | 完了条件・判定ゲートの充足を機械チェック |

## スキル

### Ideas Repository 固有スキル (`.claude/skills/` 実体配置、5 個)

| スキル | 用途 |
|-------|------|
| `/new-idea <name>` | 新しいアイデアディレクトリを作成 |
| `/advance-phase <idea-name>` | 次のフェーズに進む（判定ゲート含む） |
| `/idea-status [idea-name]` | アイデアの進捗状況を表示 |
| `/idea-summary <idea-name>` | アイデアの全体サマリーを生成 |
| `/generate-spec <idea-name>` | `04-behavior/` から仕様書 `spec.md` を自動生成 |

### Upstream 由来の汎用スキル (`.agents/skills/` 配下、10 個)

`skills-lock.json` で `Fandhe-AI/agent-cli-skills` と同期している共通スキル群。

| カテゴリ | スキル |
|---------|-------|
| 共通 | `create-commit`, `create-issue`, `create-plan`, `create-pr` |
| 実装系 | `implement-issue`, `implement-issue-tree`, `implement-review`, `implement-review-pr` |
| ドキュメント | `update-docs`, `comment-code` |

`implement-issue-tree`（イシューツリーの並列自動実装）は `.claude/workflows/implement-issue-tree.js`（`.agents/skills/implement-issue-tree/script/` への相対 symlink）を workflow スクリプトとして使用する。前提（`gh auth` / sub_issues API 疎通）と使い方はスキルの `SKILL.md` を参照。
上流貢献用の `contribute-skill` / `sync-skills-lock` は未同梱。利用する場合は `npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>` で取り込む（使い方は [`docs/guide/skill-development.md`](./docs/guide/skill-development.md) を参照）。

## Fandhe-AI エコシステム

`skills-lock.json` は [Fandhe-AI/agent-cli-skills](https://github.com/Fandhe-AI/agent-cli-skills) をソースとし、スキルの出所と SHA256 を記録している。スキルを改修した場合は `/contribute-skill <skill-name>` で upstream へ PR を作成し、マージ後に `/sync-skills-lock` でハッシュを同期する。新しいスキルを取り込むには `npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>` を実行する。
