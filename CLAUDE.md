# Ideas Repository

アイデアのブレインストーミングから要件定義・タスク分解・ロードマップ作成までを Claude Code で体系的に管理するリポジトリ。

## ワークフロー

アイデアは以下の6フェーズを順に進行する。フェーズ間には判定ゲートがある。

| フェーズ | ファイル | 内容 |
|---------|---------|------|
| 1. ブレスト | `01-brainstorm.md` | アイデアの発散・要件概要の固め |
| 2. PoC計画 | `02-poc-plan.md` | 検証すべき項目の洗い出し |
| 3. PoC実施 | `03-poc/` | 各PoC項目の検証と結果記録 |
| 4. 要件定義 | `04-requirements.md` | PoC結果を踏まえた詳細要件 |
| 5. タスク分解 | `05-tasks.md` | 要件項目ごとの具体的タスク |
| 6. ロードマップ | `06-roadmap.md` | マイルストーンとスケジュール |

### 判定ゲート

- Phase 1→2: 追求判定（PoCの価値があるか）
- Phase 3→4: Go/No-Go判定（最重要）
- Phase 4→5: スコープ確認
- Phase 6完了: 着手判定

### フィードバックループ

フェーズは逆戻り可能。README.md のステータスで「🔁 再検討中」を使用する。

## ディレクトリ構造

```
ideas/
├── docs/guide/        # 使い方ガイド
├── _templates/        # フェーズテンプレート
└── ideas/<name>/      # 各アイデア（kebab-case）
```

## 規約

- アイデア名: kebab-case（例: `ai-code-review-tool`）
- ドキュメント: 日本語で記述
- 各フェーズのドキュメントは `_templates/` のテンプレートに従う
- README.md の status フィールドを常に最新に保つ
- git commit は各フェーズの区切りで行う

## エージェント

- `brainstorm`: ブレインストーミングの促進
- `poc-planner`: PoC 項目の特定と計画
- `requirements`: 要件の分析と整理
- `task-decomposer`: タスクの分解と見積もり
- `roadmap`: ロードマップの構築

## スキル

- `/new-idea <name>`: 新しいアイデアディレクトリを作成
- `/advance-phase <idea-name>`: 次のフェーズに進む
- `/idea-status [idea-name]`: アイデアの進捗状況を表示
- `/idea-summary <idea-name>`: アイデアの全体サマリーを生成
