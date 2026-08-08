# `.claude/settings.local.json` の意図記録

このファイルは `.claude/settings.local.json` に書かれている特殊な許可・設定の**存在理由**を記録します。JSON 本体はコメントを持てないため、意図を補完する目的でここに書きます。

**値は変更しません** — このドキュメントは現状の意思決定の背景を可視化するためだけに存在します。

## 特殊許可と意図

### 1. `GIT_SSL_NO_VERIFY=1` 版の `gh` / `git`

```json
"Bash(GIT_SSL_NO_VERIFY=1 gh api:*)",
"Bash(GIT_SSL_NO_VERIFY=1 gh auth:*)",
"Bash(GIT_SSL_NO_VERIFY=1 gh issue:*)",
...
"Bash(GIT_SSL_NO_VERIFY=1 git ls-remote https://github.com/Fandhe-AI/team-hub-spec.git HEAD)",
```

**意図**: sandbox 環境では企業ネットワークの中間証明書が TLS 検証に通らない場合があり、`gh` / `git` 実行時の TLS 警告をスキップする必要があります。ユーザーの auto-memory `feedback_sandbox_tls.md`（`~/.claude/projects/-Users-nancy-fandhe---ideas/memory/`）に記録されているワークアラウンドです。

**使い所**: 上流貢献スキル `contribute-skill` / `sync-skills-lock` を取り込んだ後、upstream clone / push を行う際に sandbox 環境で必要になります。

### 2. `"defaultMode": "bypassPermissions"`

**意図**: 開発速度優先のためユーザーが明示的に選択した設定です。本リポジトリのスキル・エージェントを高頻度で使い回すため、都度の確認ダイアログを避けたい意図があります。

**リスク**: 未知のコマンドでも許可スキップで通るため、`.agents/skills/` / `.claude/skills/` の SKILL.md を読む前に新規 CLI を実行しないよう注意が必要です。

### 3. `"dangerouslyDisableSandbox": true`

**意図**: sandbox 制約に起因するファイル書き込みエラー・ネットワーク拒否など、`GIT_SSL_NO_VERIFY=1` 単独では回避できないケースの退避弁として存在します。

**リスク**: sandbox を常時無効化しているわけではなく、`"sandbox.enabled": true` と組み合わせて **必要なコマンドだけに bypass を適用** する運用（sandbox フレームワーク側で制御）が前提です。

### 4. `"excludedCommands"` — `gh`, `git`, `pnpm`, `biome`, `find`, `ls`, `wc`, `python3`, `turbo`

```json
"excludedCommands": ["gh", "git", "pnpm", "biome", "find", "ls", "wc", "python3", "turbo"]
```

**意図**: 高頻度で使う開発コマンドは sandbox 評価をスキップし、実行速度を優先する設定です。

### 5. 一過性の `python3 -c "..."` 許可

```json
"Bash(python3 -c \"import sys, json; d = json.load(sys.stdin); ...\")",
```

**意図**: `ideas/team-hub/` プロジェクトの GraphQL レスポンス JSON を整形する用途で追加された許可です。

**削除候補**: team-hub プロジェクトが submodule 化され、当該ロジックが別リポジトリに移動したため、本リポジトリの settings.local.json からは削除可能です。ただし **現時点では値を変更せず** 意図記録のみ行います。

### 6. 一過性の `/tmp/claude-501/...` パス許可

```json
"Bash(cp -R /tmp/claude-501/automation-spec-clone/.agents /tmp/claude-501/team-hub-spec-push/)",
"Bash(python3 /tmp/claude-501/add-items.py)",
```

**意図**: team-hub / automation プロジェクトの submodule 化作業中に一時的に必要だった許可です。

**削除候補**: submodule 化が完了した現在は不要です。値は変更せず意図記録のみ行います。

## 運用ルール

- `.claude/settings.local.json` の **値は本ドキュメントの存在によって自動的に変更されません**。値を変えたい場合は別途ユーザーの明示的な指示を受けてから実施します。
- 新しい許可を追加する場合は、本ドキュメントに意図を追記してください。
- `/contribute-skill` / `/sync-skills-lock` は `npx skills add` により `.agents/skills/` に取り込み済みです（Fandhe-AI/agent-cli-skills#1 マージ済）。これらを sandbox 環境で実行する場合、以下のコマンドパターンが必要になる可能性があります（現状は `Bash(git clone *)` 等でカバーされています）：
  - `Bash(GIT_SSL_NO_VERIFY=1 gh pr create:*)`
  - `Bash(GIT_SSL_NO_VERIFY=1 gh repo clone:*)`

  sandbox 環境での GitHub 操作の詳細は [`../docs/sandbox-tls.md`](../docs/sandbox-tls.md) を参照。

## 参考

- [`../.claude/rules/convention.md`](../.claude/rules/convention.md) — Conventional Commits・ブランチ命名規約
- [`../docs/guide/skill-development.md`](../docs/guide/skill-development.md) — 上流貢献フロー
