# 委譲先マッピング（作成・編集フェーズ）

## 原則

main エージェントはビヘイビア定義以降のフェーズ文書を直接書き起こさない。下表の phase エージェントへ必ず委譲し、main は完了後の確認ゲートのみを担う。

調査・設計フェーズ（Phase 1〜3）の委譲は [`delegation.md`](delegation.md) を参照する。

## 委譲先マッピング

| 対象 | 委譲先 `subagent_type` | model |
|-----|----------------------|-------|
| `ideas/<name>/04-behavior/` — ビヘイビア分割設計・ID 採番・優先度／ステータス（レガシー: `04-requirements.md`） | `behavior` | sonnet |
| `ideas/<name>/05-tasks.md` — タスク分解・工数・依存関係・担当区分 | `task-decomposer` | sonnet |
| `ideas/<name>/06-roadmap.md` — マイルストーン・タイムライン・リスク | `roadmap` | sonnet |
| フェーズ文書の整合性・トレーサビリティレビュー（読取専用） | `doc-reviewer` | sonnet |
| 完了条件・判定ゲートの機械チェック | `gate-checker` | haiku |

## 入出力の受け渡し

| 委譲先 | 主な入力 | 主な出力 |
|--------|---------|---------|
| `behavior` | `03-poc/` の検証結果・`01-brainstorm.md` の要件概要 | 優先度・ステータス付きビヘイビア（`<PREFIX>-N`）・画面／API／横断ファイル群 |
| `task-decomposer` | `04-behavior/` のビヘイビア（`<PREFIX>-N`） | 依存関係・担当区分・工数・対象ビヘイビアを含むタスク（TASK-N） |
| `roadmap` | `05-tasks.md` のタスク（TASK-N） | マイルストーン・タイムライン・着手判定欄 |

## フェーズ越境の作法

ある phase エージェントが前フェーズの成果に不足・矛盾を発見した場合、**自分で前フェーズ文書を書き換えず**、main へ「Phase N への逆戻りが必要」と提案する。main が [`phase-gate.md`](phase-gate.md) の逆戻り手順に従って判断・対応する。

例: `behavior` が PoC 不足を発見した場合 → `behavior` は指摘のみ。main が Phase 2/3 への逆戻りを判断する。

## 完了ゲート（判定ゲートの確認）

phase エージェントへの委譲後、main は以下を確認してから次フェーズへ進む。

1. **完了条件の充足** — `gate-checker` でフェーズ完了条件（[`phase-gate.md`](phase-gate.md)）を機械チェックする。
2. **品質レビュー** — `doc-reviewer` でテンプレ準拠・トレーサビリティ・ビヘイビアのテスト可能性を確認する。
3. **判定ゲートの記録** — 判定ゲートを通過する際は、ユーザー判断を受けて該当フェーズ文書末尾の「判定」節に `結果 / 理由 / 日付` を記録する。ゲートは [`phase-gate.md`](phase-gate.md) を source of truth とする全 4 種: 追求判定（Phase 1→2）/ Go/No-Go（Phase 3→4）/ スコープ確認（Phase 4→5）/ 着手判定（Phase 6 完了）。本ファイル（作成・編集フェーズ）が直接扱うのはスコープ確認と着手判定で、追求判定・Go/No-Go は調査・設計フェーズ（[`delegation.md`](delegation.md)）で記録する。
4. **コミット** — `create-commit` スキルでフェーズの区切りごとに記録する（[`convention.md`](convention.md)）。

## 仕様書の自動生成

人間・クライアント向け仕様書 `ideas/<name>/spec.md` は `/generate-spec <idea-name>` スキルで `04-behavior/` から main が生成する（[`document-quality.md`](document-quality.md) のビヘイビア SSOT 原則）。phase エージェントには委譲しない。

## GitHub Issue 化・プロジェクト展開との連携

タスク分解・ロードマップの成果を GitHub に展開する場合は、エージェント委譲ではなくスキルを main が起動する。

- `/create-issue-tree` — Phase 分割した Issue ツリーを起票
- `/implement-issue-tree` — 配下サブ Issue を worktree で並列実装
- `project-add-items` / `project-create-issues` — プロジェクトボードへの展開

上記のスキルは本テンプレートには未同梱の upstream スキル。利用する場合は `npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>` で取り込む。

## 委譲しないケース（main が直接行う）

- 秘密情報（トークン・API キー・`.env`）を含む変更は委譲先に渡さず main が確認する。
- 判定ゲートの結果記録・README ステータス更新。
- git コミット・PR・gh 操作などの外部副作用。

## 関連ファイル

- [`delegation.md`](delegation.md) — 調査・設計フェーズの委譲ハブ
- [`phase-gate.md`](phase-gate.md) — フェーズ完了条件・判定ゲート・逆戻り手順
- [`document-quality.md`](document-quality.md) — トレーサビリティ・受け入れ基準の品質基準
