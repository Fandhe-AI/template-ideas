# 委譲ハブ（調査・設計フェーズ）

## 委譲の原則

main エージェントは **対話・計画・委譲・報告** に徹する。token を消費する作業（発散・調査・検証・文書構造化）はすべて専門エージェントへ渡す。main がフェーズ文書を直接書き起こしたり、長時間の調査を抱え込んだりしない。

委譲先が見つからない軽微な作業（README ステータスの 1 行更新・判定節への記録など）は main が直接行ってよい。

## パスベースの目安

変更・調査の対象パスで作業モードを判断する。

| 対象パス | モード | 参照ルール |
|---------|-------|-----------|
| `ideas/<name>/01-brainstorm.md`〜`03-poc/` | 調査・設計モード | 本ファイル |
| `ideas/<name>/04-behavior/`〜`06-roadmap.md`（レガシー: `04-requirements.md`〜） | 作成・編集モード | [`delegation-impl.md`](delegation-impl.md) |
| `_templates/` `docs/` `.claude/` のみ | メタ編集（main 直接可、規模が大きければ委譲） | — |

フェーズは順序があるため、前フェーズの完了条件（[`phase-gate.md`](phase-gate.md)）を満たさないうちに後続フェーズのエージェントを起動しない。

## 委譲先マッピング（調査・設計系）

| やりたいこと | 委譲先 `subagent_type` | model |
|------------|----------------------|-------|
| Phase 1: アイデア発散・課題深掘り・要件概要整理（`01-brainstorm.md`） | `brainstorm` | opus |
| Phase 2: PoC 項目特定・検証計画・Go/No-Go 基準（`02-poc-plan.md`） | `poc-planner` | opus |
| Phase 3: PoC 実施・技術検証・成功基準照合（`03-poc/<item>/`） | `sub-investigator` | sonnet |
| 類似サービス・市場・外部技術仕様の調査 | `reference-researcher` | sonnet |
| 想定外の問題調査・情報収集・データ取得 | `sub-investigator` | sonnet |
| フェーズ文書の整合性・テンプレ準拠レビュー（読取専用） | `doc-reviewer` | sonnet |
| 完了条件・判定ゲートの機械チェック | `gate-checker` | haiku |
| 広範なファイル探索（結論のみ必要） | `Explore`（組込エージェント） | — |

## パスベース切り替え（フェーズ → 委譲先）

| 対象パス | 委譲先 | model |
|---------|--------|-------|
| `ideas/<name>/01-brainstorm.md` | `brainstorm` | opus |
| `ideas/<name>/02-poc-plan.md` | `poc-planner` | opus |
| `ideas/<name>/03-poc/<item>/` | `sub-investigator`（検証）/ `poc-planner`（計画修正） | sonnet / opus |

## 委譲時の指示に含める情報

委譲先エージェントを起動するときは以下を明示する。

- 対象アイデア名（kebab-case）とフェーズ
- 編集・調査対象ファイルの絶対パス
- 参照すべきテンプレート（`_templates/`）と前フェーズの成果
- 期待する成果物（埋めるべき節・未解決疑問点の列挙など完了条件）
- スコープ外の明示

## フェーズ移行

ビヘイビア定義以降の作成・編集に入る際は [`delegation-impl.md`](delegation-impl.md) を参照し、対応する phase エージェントへ委譲する。

## 委譲しないケース（main が直接行う）

- README.md のステータス記号更新（[`convention.md`](convention.md) のステータス記号節）
- 判定ゲートの「判定」節への結果記録（ユーザー判断を受けて main が記録）。本フェーズ（調査・設計）が直接扱うのは追求判定（Phase 1→2）と Go/No-Go（Phase 3→4）。スコープ確認・着手判定は作成・編集フェーズ（[`delegation-impl.md`](delegation-impl.md)）で記録する。全 4 ゲートは [`phase-gate.md`](phase-gate.md) を参照
- git コミット・PR 作成（`create-commit` / `create-pr` スキル）
- 進捗確認（`/idea-status` / `/idea-summary` スキル）

## 関連ファイル

- [`delegation-impl.md`](delegation-impl.md) — 作成・編集フェーズの委譲マッピング
- [`phase-gate.md`](phase-gate.md) — フェーズ完了条件・判定ゲート
- [`document-quality.md`](document-quality.md) — トレーサビリティ・テンプレ準拠
- `CLAUDE.md` — エージェント／スキル一覧
