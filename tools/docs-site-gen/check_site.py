#!/usr/bin/env python3
"""docs サイトの生成前検証（nav.toml・site/assets・Markdown の事前チェック）。

# 役割・境界

`build-local.sh`（ローカルと CI 共通）の最初の工程として呼ばれ、生成器（fandhe-frontend
docs-site）に渡す前に「生成器は通すが公開物として壊れる」
入力を止める。生成器自身の検査（リンク検査・nav スキーマ検査）と重複させず、生成器が
検知できない次の 3 点を担う（`[site]` のブランド値の検証は上流の規則と揃えた `_common.check_site_values`）。

1. `[site]` のブランド値と base_path: 必須 6 キーの欠落（未指定だと上流の既定表示が公開される）と
   上流が拒否する値を止める。GitHub Pages のプロジェクトサイトは `/<repo>/` 配下で配信されるため、
   base_path が repository_url から導出した値と一致しないと、全アセットと内部リンクが 404 になる。
2. 予約アセット名: `site/assets/` に生成物と同名のファイルがあると生成器がビルドエラーにする。
   エラー文が分かりにくいため事前に具体名で報告する。
3. 未置換プレースホルダー（`__SGP_*__`）の残存。

nav の path が `/themes/` 等の上流ショーケースの接頭辞で始まっても検査しない。`build-local.sh` は
常に `--no-page-sections` を付けて生成し、上流がその指定でショーケースの注入を止めるため。
このフラグを外す変更をする場合は、予約パス検査の復活が要る（`tests/rev-pin.test.mjs` が欠落を検出する）。

加えて、`[site]` の必須キーが無く旧 brand.toml が残る場合は、更新モードの移行案への案内をエラー文に足す（存在だけを見る）。

警告のみ（終了コードに影響しない）: Markdown の画像記法（上流は画像非対応）、base_path を
含まない絶対パスリンク、THIRD-PARTY-LICENSES の欠落。

終了コード: 0 問題なし / 1 エラーあり / 2 入力不正（ファイル欠落・構文違反）。
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# `-I`（隔離モード）では起動スクリプトのディレクトリが sys.path に入らないため、自分で足す。append にして、
# 同じディレクトリに標準モジュール名のファイル（argparse.py 等）があっても標準ライブラリを先に解決させる。
sys.path.append(str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    PLACEHOLDER_RE, SITE_REQUIRED_KEYS, SubsetError, check_site_values, parse_nav, parse_repository_url, pages_base_path,
    read_bounded_text, resolves_inside, sanitize,
)

# build.rs の RESERVED_ASSET_NAMES と同一（FF_REV 更新時に再確認する。SKILL.md 参照）。
RESERVED_ASSET_NAMES = {
    "site.css", "site-primitives.css", "skip-nav.css", "pre-styled-ui.css",
    "primitives-showcase.css", "admonition.css", "site.js", "theme-init.js",
    "favicon.svg", "search-index.json", "image-demo.svg", "blocks.css",
    "wireframes.css", "blocks-demo-product.svg", "blocks-demo-avatar.svg",
    "blocks-demo-logo.svg", "blocks-demo-screenshot.svg", "blocks-demo-background.svg",
}
RESERVED_ASSET_DIRS = {"search-index"}

# 入力（nav.toml・Markdown）は信頼しない。`[^\]]*` のような上限なしの繰り返しは、細工した入力で
# 最悪 O(n²) になるため長さを制限する。ファイル自体も読み取りサイズに上限を付ける。
_IMAGE_RE = re.compile(r"!\[[^\]\n]{0,300}\]\([^)\n]{0,500}\)")
_ABS_LINK_RE = re.compile(r"(?<!!)\[[^\]\n]{0,300}\]\((/[^)\s]{0,500})\)")
_INLINE_CODE_RE = re.compile(r"`[^`\n]{0,300}`")
NAV_MAX_BYTES = 1024 * 1024
MD_MAX_BYTES = 1024 * 1024
WORKFLOW_MAX_BYTES = 256 * 1024


def _strip_fences(text: str) -> str:
    """フェンスコードブロックを除く（行単位の単一走査。未閉じのフェンスは末尾まで除く）。"""
    out, fenced = [], False
    for line in text.split("\n"):
        if line.startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return "\n".join(out)


def _read_in_root(root_real: Path, path: Path, cap: int) -> str:
    """root 内に解決されるファイルだけを、上限付きで読む。root 外（`.git` 配下を含む）へ解決されるものは読まない。"""
    rel = path.relative_to(root_real) if path.is_relative_to(root_real) else path
    if path.is_symlink():
        # root 内を指す symlink（`site/nav.toml -> ../.env` など）も辿らない。リンク先の内容の断片が
        # パースエラーとして出力に出るのを防ぐ。
        raise ValueError(f"{rel} がシンボリックリンクのため読まない（通常ファイルにする）")
    if not resolves_inside(root_real, path):
        raise ValueError(f"{rel} が対象リポジトリの外（または .git 配下）へ解決される。読まない")
    try:
        return read_bounded_text(path, cap)
    except (OSError, ValueError, UnicodeDecodeError) as e:
        raise ValueError(f"{rel} を読めない: {e if isinstance(e, ValueError) and not isinstance(e, UnicodeDecodeError) else type(e).__name__}") from e


def check(root: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    nav_path = root / "site" / "nav.toml"
    try:
        tables = parse_nav(_read_in_root(root, nav_path, NAV_MAX_BYTES))
    except (SubsetError, ValueError) as e:
        raise ValueError(f"site/nav.toml を読めない: {e}") from e

    # 1. [site] の検証と base_path の整合。上流は [site] の再掲を同じ文脈として積むため全テーブルを合算し、
    # 同名キーの重複は上流と同じく拒否する。brand.toml はビルドで読まれないため内容は読まない（[site] の必須キー欠落時に限り、存在だけを見て移行の案内を足す）。
    values: dict[str, str] = {}
    for t in tables:
        if t.header != "site":
            continue
        for k, v in t.values.items():
            if k in values:
                errors.append(f"site/nav.toml line {t.line}: [site] のキー `{sanitize(k, 60)}` が重複している")
            values[k] = v
    errors.extend(f"site/nav.toml {p}" for p in check_site_values(values))
    # 旧構成の brand.toml が残り、[site] の必須キーが無い = 旧構成から未移行。存在だけを見て内容は読まず、symlink も辿らない
    legacy_brand = root / "tools" / "docs-site-gen" / "brand.toml"
    if any(k not in values for k in SITE_REQUIRED_KEYS) and resolves_inside(root, legacy_brand.parent) \
            and os.path.lexists(legacy_brand):
        errors.append(
            "旧構成の tools/docs-site-gen/brand.toml が残っている（ビルドでは読まれない）。setup-github-pages の更新モード"
            "（scaffold.py）を実行すると、brand.toml から [site] への移行案が出る。案を確認して nav.toml の [site] へ"
            "キー単位で追記する")
    base = values.get("base_path", "")
    parsed = parse_repository_url(values["repository_url"]) if "repository_url" in values else None
    if parsed is not None and base != pages_base_path(*parsed):
        errors.append(
            f"site/nav.toml の base_path が `{base}`。repository_url（{values['repository_url']}）から導出した"
            f"公開パスは `{pages_base_path(*parsed)}`（User/Org サイトは空、プロジェクトサイトは /<repo>）"
        )

    # nav が参照する Markdown（プレースホルダー検査と警告の対象）
    sources = [t.values["source"] for t in tables if "source" in t.values]

    # 2. 予約アセット名
    assets = root / "site" / "assets"
    if resolves_inside(root, assets) and assets.is_dir():   # 実体の検証が先（is_dir は親 symlink を辿って外を見る）
        for child in sorted(assets.iterdir()):
            if child.is_dir() and child.name in RESERVED_ASSET_DIRS:
                errors.append(f"site/assets/{child.name}/ は予約ディレクトリ（生成物と衝突）")
            elif child.name in RESERVED_ASSET_NAMES:
                errors.append(f"site/assets/{child.name} は予約アセット名（生成物と衝突しビルドエラーになる）")

    # 3. プレースホルダー残存（nav・nav が参照する Markdown・workflow）
    scan = [nav_path, root / ".github" / "workflows" / "pages.yml"]
    scan += [root / s for s in sources if not Path(s).is_absolute() and ".." not in Path(s).parts]
    for f in scan:
        # 実体の検証が先。root 外へ解決されるものは（存在の有無にかかわらず）読まずにエラーにする
        if resolves_inside(root, f) and not os.path.lexists(f):
            continue
        try:
            body = _read_in_root(root, f, WORKFLOW_MAX_BYTES if f.suffix == ".yml" else MD_MAX_BYTES)
        except ValueError as e:
            errors.append(str(e))   # root 外へ解決される・大きすぎる・読めない: 読まずにエラー
            continue
        found = sorted(set(PLACEHOLDER_RE.findall(body)))
        if found:
            errors.append(f"{f.relative_to(root)} に未置換のプレースホルダー: {', '.join(found)}")

    # 警告: Markdown（コードフェンス内は除外）
    for s in sources:
        f = root / s
        if Path(s).is_absolute() or ".." in Path(s).parts or not resolves_inside(root, f) or not os.path.lexists(f):
            continue  # 生成器が拒否・報告する（root 外へ解決されるものは、上のプレースホルダー検査でエラーにしている）
        try:
            body = _INLINE_CODE_RE.sub("", _strip_fences(_read_in_root(root, f, MD_MAX_BYTES)))
        except ValueError:
            continue  # root 外へ解決される・大きすぎる・読めない: 上のプレースホルダー検査で既にエラーにしている
        if _IMAGE_RE.search(body):
            warnings.append(f"{s}: 画像記法 ![](…) は上流が非対応（`!` + リンクとして描画される）")
        for link in _ABS_LINK_RE.findall(body):
            if base and not (link == base or link.startswith(base + "/")):
                warnings.append(f"{s}: 絶対パスリンク `{link}` が base_path `{base}` を含まない（リンク検査で失敗する）")

    tpl = root / "THIRD-PARTY-LICENSES"
    if not (resolves_inside(root, tpl) and tpl.is_file()):
        warnings.append("THIRD-PARTY-LICENSES が無い（build-local.sh --write-third-party で生成する）")
    return errors, warnings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", type=Path, default=Path("."), help="対象リポジトリのルート")
    args = ap.parse_args(argv)
    root = args.root.resolve()
    try:
        errors, warnings = check(root)
    except ValueError as e:
        print(f"エラー: {sanitize(e, 500)}", file=sys.stderr)
        return 2
    for w in warnings:
        print(f"警告 {sanitize(w, 500)}", file=sys.stderr)
    for e in errors:
        print(f"NG {sanitize(e, 500)}", file=sys.stderr)
    if errors:
        return 1
    print("check_site ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
