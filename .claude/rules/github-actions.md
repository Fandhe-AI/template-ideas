---
paths:
  - ".github/workflows/**"
---

# GitHub Actions ルール

`.github/workflows/` を編集するときの方針をまとめます。現在はキャッシュ方針のみを定めます。

## キャッシュ方針

GitHub Actions のキャッシュ（`actions/cache`・`actions/setup-node` の `cache`・`Swatinem/rust-cache`・
Fandhe-AI/actions の `rust-base-ci.yml` の `cache` 入力など）を追加・変更するときの方針です。
効かないキャッシュは復元時間と容量を浪費し、他のキャッシュを追い出すため、「入れれば速くなる」とは考えません。

### 現状（2026-10-11 時点）

- キャッシュは 1 件・約 4 MiB です。`pages.yml` の `Cache docs-site install`（docs-site の `cargo install` の出力先）で、
  `pages.yml` は `main` への push と手動実行でのみ動きます
- `ci.yml` は `rust-base-ci.yml` を `cache` 入力なし（既定 false）で呼んでおり、キャッシュを使っていません

### 前提: 容量と課金

- リポジトリあたりの上限は 10 GB（Org 設定も 10 GB）です。超えると最終アクセスの古い順に追い出され、
  7 日間アクセスの無いキャッシュは削除されます
- Org の Actions 予算は $0 で、超過時は停止します。そのため 10 GB を超える上限は使えません
  （上限を上げると、10 GB を超えた時点でキャッシュが読み取り専用になります）。上限・予算の変更はユーザーが判断します

### 入れる前に効果を測る

- self-hosted runner ではツールチェーン・pnpm store・`CARGO_TARGET_DIR` などがジョブをまたいで残ることがあり、
  GitHub のキャッシュが無意味（復元時間だけかかる）な場合があります。本リポジトリは GitHub ホステッドですが、
  private の派生リポジトリで self-hosted を使う場合は特に確かめます
- 組織内の実例
  - mirror-ui: pnpm キャッシュの復元に 1 ジョブ平均 75 秒かけていましたが、install は `downloaded 0` で効果が無かったため撤去しました
  - team-hub: `Swatinem/rust-cache` が `./target` を保存対象にしていましたが、runner の `CARGO_TARGET_DIR` が別の場所で
    registry しか保存されておらず、さらに後処理が共有 `CARGO_HOME` の crate を消していたため撤去しました
- キャッシュを足す・残す前に、キャッシュ有無のジョブログで効果を確かめます。見るのはパッケージの `downloaded` 件数、
  依存の再ビルド数（`Compiling` の行数）、復元にかかった秒数です

### 保存は main への push だけ

PR から保存したキャッシュは `refs/pull/<N>/merge` スコープに入り、その PR からしか読めないのに容量を共有し、
`main` のキャッシュを追い出します。保存は `main` への push に限ります。

- `actions/cache` は restore（全イベント）と save（`main` の push のみ）に分けます

    ```yaml
    - name: Restore cache
      id: cache
      uses: actions/cache/restore@<sha> # vX.Y.Z
      with:
        path: <path>
        key: <key>
        restore-keys: <prefix>
    # ...ビルド・テスト...
    - name: Save cache
      if: github.event_name == 'push' && github.ref == 'refs/heads/main' && steps.cache.outputs.cache-hit != 'true'
      uses: actions/cache/save@<sha> # vX.Y.Z
      with:
        path: <path>  # restore と同じ
        key: ${{ steps.cache.outputs.cache-primary-key }}
    ```

- `Swatinem/rust-cache` は `save-if: ${{ github.ref == 'refs/heads/main' }}` を付けます
- `ci.yml` の `rust-base-ci.yml` で `cache: true` にする場合は、`cache-save: ${{ github.ref == 'refs/heads/main' }}` も渡します
  （`cache-save` の既定は true のため、渡さないと PR でも保存します）
- `actions/setup-node` の `cache: pnpm` のように restore と save が一体の action は、PR でも保存する点に注意します

### キーの設計

- キーには中身のハッシュ（lockfile など）を入れます。`github.sha`・`github.run_id` など毎回変わる値は入れません
  （入れる場合は restore-keys の前方一致で直近を拾う設計にし、保存は `main` に限ります）
- `hashFiles('**/Cargo.lock')`・`hashFiles('**/pnpm-lock.yaml')` のような再帰 glob は使わず、ビルド対象に本当に入る
  ルートの lockfile を指定します。再帰 glob では `.agents/skills/*/samples/**` などスキルのサンプルの lockfile が混入し、
  依存が変わらないのにキーが変わって全キャッシュを作り直します（fandhe-browser・fandhe-frontend・fandhe-db・
  fandhe-container・template-frontend-react_router で発生）
- ビルド成果物（Rust の `target/` など）をキャッシュするなら、キーにツールチェーンの版を入れます（`rustc -vV` の
  release・commit-hash、`dtolnay/rust-toolchain` の `cachekey` 出力など）。入れないと runner イメージの更新後も古い成果物に
  exact hit し続け、exact hit では再保存されないため依存を毎回全再ビルドします（fandhe-db で依存 135 crate を毎回再ビルドしていました）。
  本リポジトリの `rust-toolchain.toml` は `stable` 追従のため、この点が効きます
- restore-keys で前方一致の部分復元を許し、キーが変わっても cold にならないようにします。
  例外は、部分復元した中身が使えないものです。`pages.yml` は別の `FF_REV` の docs-site を復元しないよう完全一致のみで
  復元しており、このような場合は理由をコメントに書きます

### サイズを抑える

- 1 世代（キャッシュ種別ごとの最新 1 件）の合計が 10 GB に余裕をもって収まるようにします。
  キャッシュ種別を増やすときは「1 件のサイズ × 種別（ジョブ）× OS」を見積もります
- Rust なら保存前に workspace メンバーの成果物を prune する、`CARGO_INCREMENTAL=0`、CI 限定で
  `CARGO_PROFILE_DEV_DEBUG=line-tables-only` などで縮めます（`rust-base-ci.yml` は `cache: true` で prune と
  `CARGO_INCREMENTAL=0` を行います）

### 追い出されても hit する設計

- 上限に達しても、毎回読まれる `main` の最新キャッシュは最後まで残ります（最終アクセスの古い順に追い出されるため）。
  キーの切り替えで古い世代が追い出されても、新しい世代が保存済みならミスになりません
- 保存を `main` に限り、キーが不要に変わらない状態を保てていれば上限を上げる必要はありません

### 計測コマンド

```bash
# 使用量（件数・バイト数）
gh api repos/{owner}/{repo}/actions/cache/usage
# 一覧（key・サイズ・ref・最終アクセス）
gh cache list -L 100
# 不要なキャッシュの削除（共有状態のため、key と ref を確認してから消す）
gh cache delete <id>
```

ジョブログでは次の行を見ます。

- `Cache restored from key: <key>`: primary key と一致すれば exact hit、それ以外は restore-keys による部分復元
- `Cache not found for input keys: ...`: ミス
- `Cache saved with key: <key>`: 保存された（PR で出ていれば保存条件の誤り）

### キャッシュを追加・変更する PR のチェックリスト

PR 本文に次を確認したことを書きます。

1. 効果を測った（キャッシュ有無の `downloaded` 件数・再ビルド数・復元秒数）
2. 保存が `main` への push に限られている
3. キーが中身のハッシュ（ルートの lockfile のみ）と、成果物を含むならツールチェーンの版でできており、restore-keys がある（無い場合は理由がコメントにある）
4. 1 世代の合計サイズを見積もり、10 GB に余裕をもって収まる

`pages.yml` はスキル（`setup-github-pages`）が管理するファイルのため、キャッシュの変更もスキルの手順に従います
（ファイル冒頭のコメントを参照）。
