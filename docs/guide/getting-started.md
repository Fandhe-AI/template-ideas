# はじめに

## このリポジトリの目的

アイデアを思いついてから実装に着手するまでのプロセスを、Claude Code と協働しながら体系的に進めるためのリポジトリです。

「アイデアはあるが、どこから手をつけていいかわからない」状態から、具体的なタスクとロードマップが揃った状態まで導きます。

## 前提条件

- Claude Code がインストール・設定済みであること
- このリポジトリのルートディレクトリで Claude Code を起動すること

## 基本的な使い方

### 新しいアイデアを始める

```
/new-idea <idea-name>
```

kebab-case でアイデア名を指定します（例: `ai-code-review-tool`）。

これにより:
1. `ideas/<idea-name>/` ディレクトリが作成される
2. README.md（ステータス管理）が生成される
3. ブレインストーミングが自動的に開始される

### フェーズを進める

```
/advance-phase <idea-name>
```

現在のフェーズの完了を確認し、次のフェーズに進みます。判定ゲートがある場合は、判断を求められます。

### 進捗を確認する

```
/idea-status
```

全アイデアの一覧と現在のフェーズを表示します。特定のアイデアの詳細を見るには:

```
/idea-status <idea-name>
```

### サマリーを生成する

```
/idea-summary <idea-name>
```

指定アイデアの全フェーズの内容を要約して表示します。

## エージェントの直接利用

特定のフェーズに集中して作業したい場合、エージェントを直接起動できます:

```
claude --agent=brainstorm
claude --agent=poc-planner
claude --agent=requirements
claude --agent=task-decomposer
claude --agent=roadmap
```

## ディレクトリ構成

```
ideas/
├── CLAUDE.md          # Claude Code への指示
├── docs/guide/        # このガイド
├── _templates/        # フェーズテンプレート
├── ideas/             # 各アイデアのデータ
│   └── <idea-name>/
│       ├── README.md
│       ├── 01-brainstorm.md
│       ├── ...
│       └── 06-roadmap.md
└── .claude/           # Claude Code 設定
    ├── agents/        # カスタムエージェント
    └── skills/        # スキル定義
```

## 次のステップ

- [ワークフロー全体像](./workflow-overview.md) を読んで流れを把握する
- [各フェーズの詳細ガイド](./phase-guide.md) で進め方を理解する
- `/new-idea` で最初のアイデアを始める
