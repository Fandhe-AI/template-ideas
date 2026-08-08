# AGENTS.md

## 文書の位置づけ

本リポジトリで作業するすべての AI エージェント・人間レビュアーが共通で用いるレビュー観点集。
Codex による PR 自動レビュー（`.github/workflows/codex-review.yml`。Fandhe-AI/actions の
reusable workflow を SHA 固定で呼び出す wrapper）は、PR の base コミットの本ファイルを
レビュー基準として読む。運用ガイドの正は `CLAUDE.md`、フェーズ・委譲・品質の詳細は
`.claude/rules/` を参照し、本書は重複させずレビュー判定基準に絞る。

## 優先度の定義

| 優先度 | 意味 | 扱い |
|--------|------|------|
| P0 | マージブロック。情報漏えい・判断根拠の捏造・ワークフロー破壊に直結 | 修正までマージ不可 |
| P1 | 強く推奨。フェーズ規約・品質基準への違反 | 原則修正してからマージ |
| P2 | 提案。可読性・保守性・再利用性の改善 | 任意（コメントのみ） |

## 1. セキュリティ観点

- **秘密情報の混入禁止（P0）**: API キー・トークン・パスワード・内部エンドポイントを
  フェーズ文書・PoC 成果物（`03-poc/`）・スキル・CI 設定に含めない。PoC の検証コード・
  手順メモにも実クレデンシャルを残さない（ダミー値を明示する）
- **個人情報・社外秘の混入禁止（P0）**: アイデア文書・市場調査メモに第三者の個人情報、
  NDA 下の情報、未公開の内部数値を含めない
- **調査結果の捏造（P0）**: 存在しない統計・出典 URL・競合情報の記載。
  `reference-researcher` / `sub-investigator` の成果物は出典付きであること
  （出典のない断定的な市場・技術データは P1 で指摘）
- **判定ゲートの偽装（P1）**: PoC 未実施のまま Go/No-Go 判定（Phase 3→4、最重要ゲート）を
  「実施済み・Go」と記録する変更、判定根拠なしのフェーズ進行
- **CI・ワークフローの改変（P1）**: reusable workflow 呼び出しの SHA 固定を `@main` 等の
  可動参照へ緩める変更、`permissions` の拡大、lint（markdownlint / yamllint /
  commitlint / editorconfig-checker）の無効化・除外追加による弱体化
- **スキル・エージェント定義への危険指示の混入（P0）**: `.claude/skills/` /
  `.claude/agents/` へ `--no-verify`・フック回避・無条件の破壊的操作
  （`rm -rf`・force push 等）を促す指示を埋め込まない

## 2. アーキテクチャ・設計整合の観点

- **6 フェーズワークフロー準拠（P1）**: アイデアは `ideas/<name>/` 配下に
  `01-brainstorm.md` → `06-roadmap.md` の順で `_templates/` のテンプレート構成に従う。
  フェーズ飛ばし・テンプレート逸脱・ステータストラッカー（アイデア `README.md`）の
  未更新は指摘する（`.claude/rules/phase-gate.md`）
- **文書品質基準（P1）**: フェーズ文書はトレーサビリティ（前フェーズの根拠への参照）・
  テンプレ準拠・ビヘイビア／受け入れ基準のテスト可能性を満たす
  （`.claude/rules/document-quality.md`）。検証不能なビヘイビア・受け入れ基準
  （「使いやすい」等の曖昧語のみ）は P1
- **ビヘイビア SSOT 違反（P1）**: `04-behavior/` を持つアイデアで、ビヘイビアを変更せずに
  `05-tasks.md` / `spec.md` だけを書き換える変更。`spec.md` の手動編集
  （自動生成ヘッダの削除・改変を含む。正しくは `04-behavior/` を修正して
  `/generate-spec` で再生成する）
- **エージェントの責任境界（P1）**: パスベース委譲表（`CLAUDE.md`）・各エージェントの
  「非対象」に反する構成変更。例: `doc-reviewer`（読取専用）へ編集責務を足す、
  `gate-checker`（機械チェック）へ裁量判断を足す
- **model 配分の整合（P2）**: エージェント定義の model 変更は `CLAUDE.md` の model
  配分表（発散系 = opus / 構造化・調査 = sonnet / 機械チェック = haiku）と整合させる
- **命名・記述規約（P2）**: アイデア名は kebab-case、文書は日本語・ですます調
  （`.claude/rules/japanese.md`）

## 3. 再利用・アセット化の観点

- **テンプレートの汎用性（P1）**: `_templates/` の変更は特定アイデアに固有の内容を
  ハードコードしない（アイデア固有の内容は `ideas/<name>/` 側に置く）
- **upstream スキルとの同期規律（P1）**: `.agents/skills/`（upstream 由来）を直接改変して
  `skills-lock.json` と乖離させない。改修は `/contribute-skill` で upstream
  （Fandhe-AI/agent-cli-skills）へ還元し、マージ後に `/sync-skills-lock` で同期する。
  lock の SHA256 更新を伴わない upstream スキル本体の書き換えは指摘する
- **リポジトリ固有スキルの切り分け（P2）**: 汎用化できるスキルはリポジトリ固有
  （`.claude/skills/` 実体配置）に留めず upstream への還元を検討する。逆に、
  アイデア管理固有の前提を汎用スキルへ持ち込まない
- **ドキュメント追随（P2）**: ワークフロー・エージェント・スキル構成を変更する PR は
  `CLAUDE.md` / `README.md` / `docs/guide/` の該当箇所を同時に更新する

## リポジトリ固有の観点

- **判定ゲートの記録（P1）**: フェーズ遷移 PR には対応するゲートの判定根拠
  （Phase 1→2 追求判定 / Phase 3→4 Go/No-Go / Phase 4→5 スコープ確認 / Phase 6 着手判定）が
  記録されていること。逆戻り時はステータス「🔁 再検討中」を使用する
- **コミット規約（P2）**: 日本語 Conventional Commits（`.claude/rules/convention.md`）。
  フェーズの区切りでコミットする。`--no-verify` の使用を促す・前提とする手順記述は P1
- **spec リポジトリへの引き継ぎ品質（P2）**: 完了アイデア（`04-behavior/` /
  `05-tasks.md` / `06-roadmap.md`。レガシー形式では `04-requirements.md`）は下流の
  実装リポジトリが仕様サブモジュールとして取り込む前提のため、ビヘイビア ID
  （`<PREFIX>-N`）/ TASK / MS の識別子付与と相互参照の整合を保つ
  （レガシー形式では REQ / TASK / MS。形式判定は `.claude/rules/phase-gate.md`）
