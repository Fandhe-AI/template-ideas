# 共通規約

Ideas Repository の運用にあたって守るべき命名・コミット・ステータス管理のルールをまとめます。

## 命名規約

### アイデア名

- **kebab-case** で記述します（英数字小文字とハイフンのみ）。
- 例: `ai-code-review-tool`, `freeid-onetime-service`, `team-hub`
- 日本語のアイデア名は採用しません。日本語の意味は `ideas/<name>/README.md` の概要で補足します。

### ディレクトリ・ファイル名

- フェーズドキュメント: `01-brainstorm.md` 〜 `06-roadmap.md` で固定（数字プレフィクスで順序保証）。ただし Phase 4 のみ `04-behavior/` ディレクトリ（`README.md` ＋ `screen-*.md` / `api-*.md` / 横断 md。ファイル名は kebab-case）。
- 既存アイデアの `04-requirements.md` はレガシー形式として存置します（新形式への移行はユーザーの明示指示がある場合のみ）。
- 仕様書 `spec.md` は `ideas/<name>/` 直下に `/generate-spec` で自動生成します（手書きしない）。
- PoC 項目: `03-poc/<item-name>/` 配下。`<item-name>` は kebab-case。
- スキル: `.claude/skills/<kebab-case>/SKILL.md`。
- エージェント: `.claude/agents/<kebab-case>.md`。
- SKILL ファイル名は常に大文字 `SKILL.md`。

## Conventional Commits

コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) 形式で記述します。

```
type(scope): subject
```

### type 一覧

| type | 用途 |
|------|------|
| `feat` | 新機能・新スキル・新エージェント・新テンプレート |
| `fix` | バグ修正 |
| `docs` | ドキュメントのみの変更 |
| `refactor` | 機能変更なしの整理 |
| `test` | テスト関連 |
| `chore` | 設定・補助ツール（agents の model 追加など） |
| `style` | フォーマット・空白のみ |
| `build` | ビルド・依存関係 |
| `ci` | CI 設定 |
| `perf` | パフォーマンス改善 |

### scope の例

- `agents`（`.claude/agents/`）
- `skills`（`.agents/skills/` または `.claude/skills/`）
- `templates`（`_templates/`）
- `docs`（`docs/`）
- `rules`（`.claude/rules/`）
- `<idea-name>`（アイデア個別の変更）

### 件名

- 命令形・現在形（日本語可）。
- 72 文字以内。
- 末尾にピリオドを付けません。

例:

```
feat(skills): contribute-skill を新設
docs(templates): 判定後アクション節を追加
chore(agents): model 指定を追加
fix(advance-phase): No-Go 時の逆戻り手順を追加
```

### コミット粒度

- 1 フェーズ・1 機能・1 目的ごとに 1 コミット。
- ドキュメントとコードの混在は避ける（可能な範囲で）。

## ステータス記号

`README.md` のステータステーブルで使用します。

| 記号 | 意味 |
|------|------|
| ⬜ | 未着手 |
| 🔄 | 進行中 |
| ✅ | 完了 |
| 🔁 | 再検討中（手戻り中） |
| ⏸️ | 保留 |
| ❌ | 中止 |

## PR タイトル

- コミットと同じく Conventional Commits 形式。
- PR 本文には `Summary` / `Test plan` を最低限含めます（`.agents/skills/create-pr/SKILL.md` のテンプレ参照）。

## ブランチ命名

- 機能: `feat/<short-name>`
- 修正: `fix/<short-name>`
- 上流貢献（contribute-skill 用）: `contribute/<skill-name>-<slug>`
- worktree 由来: `worktree-agent-<hash>`（自動生成）
