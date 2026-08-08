# スキル開発ガイド

Ideas Repository のスキルを改修したり、新しいスキルを追加したりする際の手順をまとめます。

## ローカルスキル vs Upstream スキル

本リポジトリのスキルは 2 系統に分かれます。

### ローカル専用スキル

`.claude/skills/` 配下に**ディレクトリ実体**で配置されているスキルです。Ideas Repository 固有のワークフロー（6 フェーズ、アイデア管理）に特化しています。

- `/new-idea` — 新しいアイデアディレクトリを作成
- `/advance-phase` — フェーズを前進させる
- `/idea-status` — 進捗を表示
- `/idea-summary` — アイデアのサマリーを生成

これらは upstream には存在せず、本リポジトリでのみメンテナンスします。

### Upstream 由来スキル

`.agents/skills/` にディレクトリ実体を持ち、`.claude/skills/` からは symlink される汎用スキルです。`skills-lock.json` で upstream とハッシュ同期しています。

- `create-commit`, `create-issue`, `create-plan`, `create-pr`
- `implement-issue`, `implement-review`, `implement-review-pr`
- `project-add-items`, `project-archive-done`, `project-create-issues`, `project-init`, `project-sync-issues`, `project-update-items`, `project-view-status`
- `update-docs`
- `contribute-skill`, `sync-skills-lock`（上流貢献用。本リポジトリには未同梱のため、利用する場合は `npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>` で取り込む）

これらの更新は upstream (`Fandhe-AI/agent-cli-skills`) と双方向に同期します。

### 新しい upstream スキルを取り込む

upstream に新スキルが追加されたら、以下のコマンドで取り込みます:

```
npx skills add Fandhe-AI/agent-cli-skills --skill <skill-name>
```

取り込みにより `.agents/skills/<skill-name>/` に実体が配置され、`.claude/skills/<skill-name>` から symlink が作成され、`skills-lock.json` に自動登録されます。

## `skills-lock.json` の役割

ルート直下の `skills-lock.json` は、upstream 由来スキルの **出所** と **ハッシュ** を記録します。

```json
{
  "version": 1,
  "skills": {
    "create-commit": {
      "source": "Fandhe-AI/agent-cli-skills",
      "sourceType": "github",
      "computedHash": "80e2dd2232..."
    },
    ...
  }
}
```

- `source`: upstream の `<owner>/<repo>`
- `sourceType`: `github` 固定（将来的な拡張枠）
- `computedHash`: upstream の SKILL.md から計算した SHA256

`ideas/team-hub/skills-lock.json` と `ideas/automation/skills-lock.json` も存在しますが、これらは submodule 配下のため、本リポジトリからは**絶対に触りません**。

## スキル構造

スキルは以下の構造を取ります。

```
.agents/skills/<skill-name>/
└── SKILL.md
```

`SKILL.md` はファイル名が常に大文字です。フロントマターには以下を記述します。

```markdown
---
name: <skill-name>
description: <ひと言説明>
argument-hint: "<引数の例>"
user-invocable: true
---

# <skill-name>

<概要>

## フロー

### Step 1: ...
...
```

## 新しいローカルスキルを追加する

Ideas Repository 専用のスキル（`.claude/skills/` 直下に実体を置くタイプ）を追加する場合：

1. `.claude/skills/<skill-name>/SKILL.md` を作成
2. frontmatter に `user-invocable: true` を入れる（ユーザーから `/` 経由で呼び出し可能に）
3. コミットする (`feat(skills): ...`)

## Upstream スキルを改修して貢献する

upstream 由来スキル（`.agents/skills/` 配下）を改修し、上流に PR を投げるフロー：

```
1. .agents/skills/<skill-name>/SKILL.md を編集
2. ローカルでコミット
3. /contribute-skill <skill-name> を実行
   → upstream を clone
   → 変更をコピー
   → Conventional Commits でコミット
   → gh pr create --repo Fandhe-AI/<repo> で PR 作成
4. upstream で PR がマージされたら
5. /sync-skills-lock を実行して computedHash を更新
6. chore(skills-lock): ... でコミット
```

### `/contribute-skill` の使い方

```
/contribute-skill create-pr
```

- 引数: 改修したスキル名
- `skills-lock.json` の `source` が `Fandhe-AI/` で始まらない場合はエラーで中止（安全弁）
- セキュリティチェック（OWASP Top 10 等）を必ず通す
- 作業ディレクトリは `/tmp/claude-<uid>/contribute-<name>-<ts>/`

詳細は [upstream 原本](https://github.com/Fandhe-AI/agent-cli-skills/blob/main/skills/contribute-skill/SKILL.md) を参照。

### `/sync-skills-lock` の使い方

```
/sync-skills-lock              # 全スキル対象
/sync-skills-lock create-pr    # 特定スキルのみ
```

- upstream の `SKILL.md` から SHA256 を再計算
- 差分を表示し、ユーザー承認後に `skills-lock.json` を更新
- **ルートの `skills-lock.json` のみが対象**（submodule 配下は対象外）

詳細は [upstream 原本](https://github.com/Fandhe-AI/agent-cli-skills/blob/main/skills/sync-skills-lock/SKILL.md) を参照。

## 注意事項

- Conventional Commits 形式を厳守します（`type(scope): subject`）。詳細は [`../../.claude/rules/convention.md`](../../.claude/rules/convention.md) を参照。
- 新規スキル（upstream にまだマージされていないもの）は `skills-lock.json` に `computedHash` を書き込みません。マージ後に `/sync-skills-lock` で反映します。
