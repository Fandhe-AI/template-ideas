#!/usr/bin/env bash
# build-local.sh: docs サイトのビルド入口。ローカルと GitHub Actions（pages.yml）が同じ
# スクリプトを通るため、「CI でだけ壊れる」差分を作らない。
#
# 対象リポジトリでは tools/docs-site-gen/build-local.sh に置かれ、リポジトリのルートは
# このスクリプトの 2 階層上として解決する（呼び出し時のカレントディレクトリに依存しない）。
#
# 工程: FF_REV 検証 → [THIRD-PARTY-LICENSES 生成（固定 URL から取得）] → check_site
#       → docs-site を cargo install（匿名・--locked。失敗時は insteadOf 書き換えの案内） → 生成（--no-page-sections） → 最小 verify・帰属表記の確認
#
# 上流（fandhe-frontend）の docs-site バイナリを、固定 rev（FF_REV）の匿名 `cargo install --git` で
# スキル管理下の target/docs-site-install へ入れて実行する。以前の「_ff/ へ shallow fetch + path 依存の
# wrapper を build」は上流が匿名 install に対応したため不要になった。wrapper（Cargo.toml・src/main.rs）と
# brand.toml は scaffold の配置物から外れており、旧構成のリポジトリに残っていても使わない（scaffold の削除候補）。
#
# 使い方: build-local.sh [--out DIR] [--clean] [--write-third-party]
#   --out DIR              出力先（既定 <root>/_site）。既存かつ非空ならエラー
#   --clean                既定の出力先 <root>/_site のみを削除してから生成する
#   --write-third-party    固定 rev の LICENSE-MIT を取得して <root>/THIRD-PARTY-LICENSES を（再）生成する
# 環境変数: CARGO_HOME / RUSTUP_HOME は呼び出し側で上書きできる（隔離ビルド用）。
# 終了コード: 0 成功 / それ以外は失敗（どの工程かは stderr の "==> " 行で分かる）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FF_URL="https://github.com/Fandhe-AI/fandhe-frontend"
INSTALL_ROOT="${SCRIPT_DIR}/target/docs-site-install"
DEFAULT_OUT="${ROOT}/_site"

OUT="${DEFAULT_OUT}"
CLEAN=0
WRITE_THIRD_PARTY=0

usage() {
  sed -n '/^# 使い方/,/^# 終了コード/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || { echo "エラー: --out には値が必要" >&2; usage; exit 2; }
      OUT="$2"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --write-third-party) WRITE_THIRD_PARTY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "エラー: 未知の引数: $1" >&2; usage; exit 2 ;;
  esac
done

# 相対パスは呼び出し時のカレントディレクトリ基準で絶対化する
case "${OUT}" in
  /*) ;;
  *) OUT="${PWD}/${OUT}" ;;
esac

# >>> guards（tests/test_rebrand.py がこの区間を取り出して単体実行する。区間の目印を消さない）
# 不変条件: このスクリプトが書く・消す先（target/・docs-site-install・THIRD-PARTY-LICENSES・既定の
# 出力先 _site/）は、(a) 対象リポジトリの実体パス（ROOT_REAL）配下に解決され、(b) 末端自体が
# symlink でないこと。`cargo install` / `mv` / `rm -r` は
# symlink を辿ってリンク先を書き換え得るため、書く前に必ずこの関数を通す。
# 唯一の例外は --out（CI は ${RUNNER_TEMP} など対象リポジトリ外へ出力する）で、guard_out が別途検査する。
#
# macOS 標準の realpath には -m が無いため、移植性のある python3 の os.path.realpath（存在しない
# パスも許容する非 strict 動作）で正規化する。
# python3 は、`-c` なら cwd、スクリプト起動ならそのスクリプトのディレクトリが sys.path の先頭に入る。対象
# リポジトリ（信頼できない場合がある）の .py（argparse.py 等の標準モジュール名）が標準ライブラリより先に
# import されないよう、すべての起動に `-I`（隔離モード: cwd・スクリプトのディレクトリ・PYTHONPATH・user site を
# 使わない）を付ける。`-B` は __pycache__ を作らない（置かれた .pyc の読み込みを避ける）。
# check_site.py も自分で自ディレクトリを sys.path の末尾に足すので、_common は import できる。
canon() { python3 -I -B -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

# 親ディレクトリだけを実体化し、末端の名前はそのまま残す。末端が symlink かの判定（-L）を
# 正規化後のパスに対して正しく行うため（`sub/../x` のように途中が未作成でも `-L` が誤って偽にならない）。
canon_leaf() {
  python3 -I -B -c '
import os, sys
p = sys.argv[1].rstrip("/") or "/"
b = os.path.basename(p)
print(os.path.realpath(p) if b in ("", ".", "..") else os.path.join(os.path.realpath(os.path.dirname(p)), b))
' "$1"
}

guard_path() {   # guard_path <path> <label>
  local p="$1" label="$2" real
  if [[ -L "${p}" ]]; then
    echo "エラー: ${label}（${p}）がシンボリックリンクのため、書き込み・削除をしない" >&2
    return 1
  fi
  real="$(canon "${p}")"
  case "${real}/" in
    "${ROOT_REAL}/"*) ;;
    *)
      echo "エラー: ${label}（${p}）が対象リポジトリの外（${real}）へ解決される。親ディレクトリが symlink の可能性" >&2
      return 1 ;;
  esac
}
# <<< guards

ROOT_REAL="$(canon "${ROOT}")"
OUT="$(canon_leaf "${OUT}")"
OUT_REAL="$(canon "${OUT}")"
DEFAULT_OUT_REAL="$(canon "${DEFAULT_OUT}")"

step() { echo "==> $*" >&2; }

# ---- FF_REV の検証（唯一の定義元は FF_REV ファイル。使用前に必ず 40 桁 hex か確認する）
step "FF_REV を検証"
FF_REV="$(tr -d '[:space:]' < "${SCRIPT_DIR}/FF_REV")"
if [[ ! "${FF_REV}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "エラー: FF_REV が 40 桁の小文字 hex ではない" >&2
  exit 1
fi

# ---- 書き込み先の安全確認（symlink 経由で対象リポジトリの外へ書かない）
guard_path "${SCRIPT_DIR}" "tools/docs-site-gen" || exit 2
guard_path "${SCRIPT_DIR}/target" "tools/docs-site-gen/target（cargo install の出力先）" || exit 2
guard_path "${INSTALL_ROOT}" "docs-site のインストール先" || exit 2
if [[ "${WRITE_THIRD_PARTY}" -eq 1 ]]; then
  guard_path "${ROOT}/THIRD-PARTY-LICENSES" "THIRD-PARTY-LICENSES" || exit 2
  if [[ -d "${ROOT}/THIRD-PARTY-LICENSES" ]]; then
    echo "エラー: THIRD-PARTY-LICENSES がディレクトリ（mv が配下へ移動してしまう）" >&2
    exit 2
  fi
fi

# ---- 出力先の安全確認
# --out は対象リポジトリの外でもよいが、末端が symlink なら拒否する（生成器・rm がリンク先を書き換えるため）。
# 対象リポジトリ内を指す場合は、実体も対象リポジトリ内に収まること（親ディレクトリ経由の脱出を防ぐ）。
if [[ -L "${OUT}" ]]; then
  echo "エラー: 出力先 ${OUT} がシンボリックリンク" >&2
  exit 2
fi
# 内外の判定は正規化後（OUT_REAL）で行う。生パスで判定すると `--out ../dist` のように実際は外へ
# 解決される指定を誤って「内」として扱い、外部出力を許す例外が効かなくなる。
case "${OUT_REAL}/" in
  "${ROOT_REAL}/"*) guard_path "${OUT}" "出力先" || exit 2 ;;
esac
if [[ "${CLEAN}" -eq 1 ]]; then
  # 削除してよいのは既定の出力先だけ（任意パスの再帰削除を許さない）
  if [[ "${OUT_REAL}" != "${DEFAULT_OUT_REAL}" ]]; then
    echo "エラー: --clean は既定の出力先（${DEFAULT_OUT}）でのみ使える" >&2
    exit 2
  fi
  if [[ -L "${DEFAULT_OUT}" ]]; then
    echo "エラー: ${DEFAULT_OUT} がシンボリックリンクのため削除しない" >&2
    exit 2
  fi
  if [[ -e "${DEFAULT_OUT}" ]]; then
    rm -r -- "${DEFAULT_OUT}"
  fi
fi
if [[ -e "${OUT}" ]] && [[ -n "$(ls -A "${OUT}" 2>/dev/null || true)" ]]; then
  echo "エラー: 出力先が既に存在し空ではない: ${OUT}（--clean か手動削除で空にする）" >&2
  exit 1
fi
case "${OUT_REAL}/" in
  "${ROOT_REAL}/site/"*)
    echo "エラー: 出力先を site/ 配下にできない（入力と混ざる）" >&2
    exit 2 ;;
esac
if [[ "${OUT_REAL}" == "${ROOT_REAL}" || "${ROOT_REAL}/" == "${OUT_REAL}/"* ]]; then
  echo "エラー: 出力先がリポジトリのルートまたはその上位ディレクトリになっている" >&2
  exit 2
fi

# ---- THIRD-PARTY-LICENSES（固定 rev の LICENSE-MIT を取得して同梱する）
# >>> third_party（tests/test_rebrand.py がこの区間を取り出して単体実行する。区間の目印を消さない）
# 取得先は固定 URL（可変部分は検証済み FF_REV のみ）。リダイレクト非追従・https 限定・時間とサイズを制限し、
# 本文が上流の著作権行・MIT の全条項（許諾・条件・免責）を含まなければ既存の THIRD-PARTY-LICENSES に触れず非 0 で停止する。
# 前提: ROOT_REAL・FF_REV が検証済みで、宛先が symlink・ディレクトリでないこと（冒頭で確認済み）。
write_third_party() {
  local license_url="https://raw.githubusercontent.com/Fandhe-AI/fandhe-frontend/${FF_REV}/LICENSE-MIT"
  local code rc size
  # trap は関数の外（EXIT）で効かせるため、一時ファイルのパスは大域変数で持つ（set -u 下でも参照できる）
  dl_tmp=""; tpl_tmp=""
  trap 'rm -f -- "${dl_tmp}" "${tpl_tmp}"' EXIT
  dl_tmp="$(mktemp "${ROOT_REAL}/.THIRD-PARTY-LICENSES.dl.XXXXXX")" || return 1
  tpl_tmp="$(mktemp "${ROOT_REAL}/.THIRD-PARTY-LICENSES.XXXXXX")" || { rm -f -- "${dl_tmp}"; return 1; }

  rc=0
  code="$(curl --fail --silent --show-error \
      --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --max-time 30 --max-filesize 65536 \
      --output "${dl_tmp}" --write-out '%{http_code}' \
      "${license_url}")" || rc=$?
  if [[ "${rc}" -ne 0 || "${code}" != "200" ]]; then
    echo "エラー: LICENSE-MIT の取得に失敗（curl 終了コード ${rc}・HTTP ${code:-?}）。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  # --max-filesize は Content-Length が無いと効かないため、実サイズも検証する
  size="$(wc -c < "${dl_tmp}" | tr -d '[:space:]')"
  if [[ -z "${size}" || "${size}" -lt 1 || "${size}" -gt 65536 ]]; then
    echo "エラー: 取得した LICENSE-MIT のサイズが範囲外（${size:-?} バイト）。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  # NUL バイトを含む本文は拒否する（NUL を除いた長さが元と違えば含む）
  if [[ "$(LC_ALL=C tr -d '\000' < "${dl_tmp}" | wc -c | tr -d '[:space:]')" != "${size}" ]]; then
    echo "エラー: 取得した LICENSE-MIT に NUL バイトが含まれる。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  local pat
  local -a pats=(
    '^Copyright \(c\) [0-9]{4} Fandhe-AI / fandhe-frontend contributors$'
    '^Permission is hereby granted, free of charge, to any'
  )
  for pat in "${pats[@]}"; do
    rc=0
    grep -Eq -- "${pat}" "${dl_tmp}" || rc=$?
    if [[ "${rc}" -eq 1 ]]; then
      echo "エラー: 取得した LICENSE-MIT に上流の著作権行または許諾文が無い。THIRD-PARTY-LICENSES は変更しない" >&2
      return 1
    elif [[ "${rc}" -ne 0 ]]; then
      echo "エラー: LICENSE-MIT の内容検査自体が失敗（grep 終了コード ${rc}）。THIRD-PARTY-LICENSES は変更しない" >&2
      return 1
    fi
  done
  # 全文の完全性: 冒頭だけの切り詰め本文や条件・免責条項を欠く本文を弾く。MIT の条項ごとの固定句が
  # 空白正規化後の本文にすべて含まれ、末尾が免責条項の最終文で終わることを要求する（改行位置の差は許容）。
  local norm phrase
  norm="$(LC_ALL=C tr -s '[:space:]' ' ' < "${dl_tmp}")" || { echo "エラー: LICENSE-MIT の正規化に失敗。THIRD-PARTY-LICENSES は変更しない" >&2; return 1; }
  norm="${norm% }"
  local -a phrases=(
    'to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software'
    'subject to the following conditions:'
    'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.'
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED'
    'IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY'
  )
  for phrase in "${phrases[@]}"; do
    if [[ "${norm}" != *"${phrase}"* ]]; then
      echo "エラー: 取得した LICENSE-MIT が MIT 本文として不完全（条件または免責条項が欠けている）。THIRD-PARTY-LICENSES は変更しない" >&2
      return 1
    fi
  done
  if [[ "${norm}" != *"OTHER DEALINGS IN THE SOFTWARE." ]]; then
    echo "エラー: 取得した LICENSE-MIT の末尾が免責条項の最終文でない（切り詰めの疑い）。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  # 呼び出し側が `|| exit 1` で受けるため、bash はこの関数内の set -e を無効にする。
  # 書き込み・chmod・mv は失敗を明示的に検査し、不完全なファイルで置き換えない。
  if ! {
    printf '%s\n' \
      "This repository's documentation site is generated with the docs-site generator of" \
      "fandhe-frontend (https://github.com/Fandhe-AI/fandhe-frontend, commit ${FF_REV})," \
      "which is licensed under MIT OR Apache-2.0. The MIT license text follows." \
      "" &&
    cat "${dl_tmp}"
  } > "${tpl_tmp}"; then
    echo "エラー: THIRD-PARTY-LICENSES の一時ファイルへの書き込みに失敗。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  # mktemp は 0600 で作るため、通常ファイルと同じ権限へ
  if ! chmod 0644 "${tpl_tmp}"; then
    echo "エラー: 一時ファイルの chmod に失敗。THIRD-PARTY-LICENSES は変更しない" >&2
    return 1
  fi
  if ! mv -f -- "${tpl_tmp}" "${ROOT_REAL}/THIRD-PARTY-LICENSES"; then
    echo "エラー: THIRD-PARTY-LICENSES への置き換えに失敗" >&2
    return 1
  fi
}
# <<< third_party

if [[ "${WRITE_THIRD_PARTY}" -eq 1 ]]; then
  step "THIRD-PARTY-LICENSES を生成"
  write_third_party || exit 1
fi

# ---- 事前検証
step "check_site"
python3 -I -B "${SCRIPT_DIR}/check_site.py" --root "${ROOT}"

# ---- docs-site をインストール（匿名・FF_REV 固定・--locked）
# 同一 FF_REV でインストール・検査済みなら cargo install 自体を省く（cargo の「最新か」判定は上流の git DB の
# clone を先に要求し、CI の cache ヒット時でも約 185 MB を取得するため）。この省略はスクリプト側の判定であり、
# install の引数や検査を変えるときはローカルの既存インストールが再利用され得る。CI は pages.yml の cache キーへ
# build-local.sh を含めて無効化している。強制的に入れ直すには INSTALL_ROOT を削除する。
step "docs-site をインストール"
#
# 依存検査（インストール前）: 固定 rev の Cargo.lock を固定 URL から取得し、docs-site から辿れる依存の
# すべてが path 依存（lock 上で source なし）であることを機械的に確認する。crates.io 等の registry・git
# 依存が FF_REV 更新で混入すると、匿名・隔離ビルドの前提と供給網の固定方針が崩れるため、fail-closed で停止する。
#
# 検査済み rev の記録（INSTALL_ROOT は Actions のキャッシュ対象）。同じ FF_REV で検査済みなら Cargo.lock を
# 再取得しない（キャッシュ済みの CI・オフライン再ビルドを、検査のためだけに壊さない）。記録は通常ファイルのみ信用する。
CHECKED_MARK="${INSTALL_ROOT}/.registry-checked"
guard_path "${CHECKED_MARK}" "registry 依存検査の記録" || exit 2
NEED_LOCK_CHECK=1
if [[ -f "${CHECKED_MARK}" && -x "${INSTALL_ROOT}/bin/docs-site" && "$(cat -- "${CHECKED_MARK}" 2>/dev/null || true)" == "${FF_REV}" ]]; then
  NEED_LOCK_CHECK=0
  step "registry 依存の検査は同一 FF_REV で検査済みの記録があるため省略"
fi
if [[ "${NEED_LOCK_CHECK}" -eq 1 ]]; then
step "registry 依存が 0 件であることを検査"
LOCK_URL="https://raw.githubusercontent.com/Fandhe-AI/fandhe-frontend/${FF_REV}/Cargo.lock"
LOCK_BODY="$(curl --fail --silent --show-error \
  --proto '=https' --proto-redir '=https' --tlsv1.2 \
  --max-time 30 --max-filesize 4194304 \
  "${LOCK_URL}")" || { echo "エラー: 固定 rev の Cargo.lock の取得に失敗。依存を検査できないためインストールしない" >&2; exit 1; }
printf '%s' "${LOCK_BODY}" | python3 -I -B -c '
import sys
try:
    import tomllib
except ImportError:
    print("エラー: Python に tomllib が無い（3.11 以上が必要）。依存を検査できないためインストールしない", file=sys.stderr)
    sys.exit(1)
root = "fandhe-frontend-docs-site"
pkgs = tomllib.loads(sys.stdin.read()).get("package", [])
by = {}
for p in pkgs:
    by.setdefault(p["name"], []).append(p)
if root not in by:
    print("エラー: Cargo.lock に %s が無い。依存を検査できないためインストールしない" % root, file=sys.stderr)
    sys.exit(1)
seen, stack, ext = set(), [root], []
while stack:
    ref = stack.pop()
    if ref in seen:
        continue
    seen.add(ref)
    # 依存の表記は "name" または "name version"（同名複数版・source 付きの場合は後者）
    name = ref.split(" ")[0]
    for p in by.get(name, []):
        if p.get("source") is not None:
            ext.append("%s %s" % (p["name"], p["version"]))
        stack.extend(p.get("dependencies", []))
if ext:
    print("エラー: registry/git 依存が混入している（%d 件）: %s" % (len(ext), ", ".join(sorted(set(ext))[:10])), file=sys.stderr)
    sys.exit(1)
print("registry 依存 0 件（docs-site から辿れる packages=%d・すべて path 依存）" % len(seen), file=sys.stderr)
'
fi

# インストール先の各階層（bin・実行ファイル・cargo の台帳ファイルを含む）が symlink でなく、対象リポジトリ内に
# 収まることを、cargo install が書く前に確認する（--root はリンク先へ書き込み得るため）。
guard_install_tree() {
  guard_path "${INSTALL_ROOT}/bin" "docs-site のインストール先 bin" || return 1
  guard_path "${INSTALL_ROOT}/bin/docs-site" "docs-site の実行ファイル" || return 1
  guard_path "${INSTALL_ROOT}/.crates.toml" "cargo install の台帳 .crates.toml" || return 1
  guard_path "${INSTALL_ROOT}/.crates2.json" "cargo install の台帳 .crates2.json" || return 1
}
guard_install_tree || exit 2
# 省略条件（すべて成立したときだけ）: 検査済み記録と bin/docs-site が揃う（NEED_LOCK_CHECK=0）、かつ cargo の台帳が
# 固定 URL と FF_REV の組でのインストールを記録している。欠落・不一致・読み取り失敗は install を実行する側へ倒す。
NEED_INSTALL=1
if [[ "${NEED_LOCK_CHECK}" -eq 0 && -f "${INSTALL_ROOT}/.crates.toml" ]] \
  && python3 -I -B -c '
import sys
try:
    import tomllib
except ImportError:
    sys.exit(1)
# .crates.toml の [v1] は "<pkg> <version> (<source>)" = ["<bin>", ...]。対象パッケージの
# エントリ自体の source が固定 URL・FF_REV の組で、かつ bin/docs-site を提供していることだけを成功とする
# （別パッケージのエントリやコメントに同じ文字列があっても一致させない）
url, rev, path = sys.argv[1], sys.argv[2], sys.argv[3]
want = "(git+%s?rev=%s#%s)" % (url, rev, rev)
try:
    with open(path, "rb") as f:
        v1 = tomllib.load(f).get("v1", {})
except Exception:
    sys.exit(1)
for key, bins in v1.items():
    parts = key.split(" ", 2)
    if len(parts) == 3 and parts[0] == "fandhe-frontend-docs-site" and parts[2] == want \
        and isinstance(bins, list) and "docs-site" in bins:
        sys.exit(0)
sys.exit(1)
' "${FF_URL}" "${FF_REV}" "${INSTALL_ROOT}/.crates.toml"; then
  NEED_INSTALL=0
fi
# cargo install 失敗時の案内（助言のみ。成否は cargo の終了コードで決まり、ここでは変えない）。
# 利用者の git 設定に `url.<書き換え先>.insteadOf = https://github.com/` があると、cargo（libgit2）が書き換えに
# 従って書き換え先（ssh 等）で取得しようとし、認証ができず失敗し得る。書き換え先の種類は判定も表示もしない。FF_URL へ実際に適用される規則がある場合だけ、
# 回避策（CARGO_NET_GIT_FETCH_WITH_CLI=true）を stderr へ案内する。この環境変数は「匿名取得」の前提を黙って
# 変えないため自動では付けない。規則の値・書き換え先は認証情報（user:token@）を含み得るので出力しない。
# `-C /` はリポジトリのローカル設定（信頼できない場合がある）を避け、cargo も読む global / system 設定だけを見る。
hint_git_rewrite() {
  [[ "${CARGO_NET_GIT_FETCH_WITH_CLI:-}" == "true" ]] && return 0
  local rules="" line value matched=0
  rules="$(git -C / config --get-regexp '^url\..*\.insteadof$' 2>/dev/null)" || return 0
  while IFS= read -r line; do
    value="${line#* }"
    [[ -n "${value}" ]] || continue
    if [[ "${FF_URL}" == "${value}"* ]]; then
      matched=1
      break
    fi
  done <<< "${rules}"
  if [[ "${matched}" -eq 1 ]]; then
    {
      echo "ヒント: git の insteadOf 設定で https://github.com/ が別の URL へ書き換えられており、"
      echo "  cargo の取得が書き換え後の URL の認証で失敗した可能性がある（書き換え先の種類は判定しない。有無だけ確認: git -C / config --get-regexp '^url\\..*\\.insteadof\$' >/dev/null && echo あり）。"
      echo "  出力すると設定キーの認証情報が端末に残るため、必ず >/dev/null で捨てる。"
      echo "  環境変数 CARGO_NET_GIT_FETCH_WITH_CLI を true にして build-local.sh を再実行すると通る場合がある。"
      echo "  ただし git CLI も書き換えに従うため、書き換え先の認証が通る環境が前提。"
      echo "  このスクリプトは匿名取得の前提を変えないため、この環境変数は自動では付けない。"
    } >&2
  fi
  return 0
}
if [[ "${NEED_INSTALL}" -eq 1 ]]; then
  install_rc=0
  GIT_TERMINAL_PROMPT=0 cargo install --git "${FF_URL}" --rev "${FF_REV}" --locked --root "${INSTALL_ROOT}" fandhe-frontend-docs-site || install_rc=$?
  if [[ "${install_rc}" -ne 0 ]]; then
    hint_git_rewrite
    exit "${install_rc}"
  fi
else
  step "docs-site のインストールは省略（同一 FF_REV でインストール・検査済み）"
fi
# インストール後・実行前にも再確認し、実行ファイルが通常ファイルであることを要求する
guard_install_tree || exit 2
if [[ ! -f "${INSTALL_ROOT}/bin/docs-site" || ! -x "${INSTALL_ROOT}/bin/docs-site" ]]; then
  echo "エラー: ${INSTALL_ROOT}/bin/docs-site が生成されていない、または実行可能な通常ファイルではない" >&2
  exit 1
fi
# 検査と install が両方通った rev だけを記録する（次回以降は Cargo.lock を再取得しない）
if [[ "${NEED_LOCK_CHECK}" -eq 1 ]]; then
  printf '%s\n' "${FF_REV}" > "${CHECKED_MARK}" || { echo "エラー: 検査済みの記録を書けない" >&2; exit 1; }
fi

# >>> verify_attribution（tests/test_rebrand.py がこの区間を取り出して単体実行する。区間の目印を消さない）
# 生成物（dist）に上流の帰属表記が残っていることを確認する。上流（docs-site）は `[site]` の値で表示を
# 組み立て、帰属表記（Built with … docs-site と MIT / Apache-2.0 のライセンスリンク 2 本）だけを必ず
# 出力する。これは MIT / Apache-2.0 の通知義務を担う部分のため、上流の DOM が変わっても黙って
# 消えないよう、文言とリンクが 1 つの連続した並びとして存在することを見る（FF_REV 更新時に実出力で再確認する）。
# 読むだけで書かない。エラーには dist からの相対パスだけを出し、ファイルの内容は出さない。
# 帰属表記の外に残る上流名・上流 URL（fandhe-frontend）は意図的に検査しない（references/maintenance.md の決定 3・決定 4、#47 の決定）。
# 理由: 上流は `[site]` の値で表示を組み立て、必須キーは check_site.py が事前に強制するため、上流の既定ブランドは
# 出力に出ない。一方、利用者が `[site]` や nav の title・repository_url・version_badge に上流名を含めるのは正当で、
# 生成器はそれらを title・サイドバー・リンク等の多数の箇所へ出す。残存検査は、その正当な出力をビルド最終段で
# 落とすか、許容区間を広げて検査が形骸化するかのどちらかになる。上流の DOM 変更（既定ブランドの混入等）の検知は、
# FF_REV 更新時の maintenance.md の手順（実出力の確認）で担う。
# 呼び出し側は `|| exit 1` で受けるため関数内の set -e は効かない。失敗は明示的に return 1 する。
verify_attribution() {
  local dist="$1" up pat list links f rel rc n=0 has_chrome
  up='https://github\.com/Fandhe-AI/fandhe-frontend'
  pat="Built with <a [^>]*href=\"${up}\"[^>]*>fandhe-frontend docs-site</a> \\(<a [^>]*href=\"${up}/blob/main/LICENSE-MIT\"[^>]*>MIT</a> OR <a [^>]*href=\"${up}/blob/main/LICENSE-APACHE\"[^>]*>Apache-2\\.0</a>\\)"

  # 生成器は symlink を出さない。あれば検査対象の外を指し得るため失敗にする
  links="$(find "${dist}" -type l)" || { echo "エラー: dist の走査（symlink 検査）に失敗した" >&2; return 1; }
  if [[ -n "${links}" ]]; then
    echo "エラー: dist に symlink が含まれる（生成器は出さない）" >&2
    return 1
  fi

  for rel in index.html 404.html; do
    [[ -f "${dist}/${rel}" ]] || { echo "エラー: ${rel} が通常ファイルとして存在しない" >&2; return 1; }
  done

  # assets/ は利用者の静的ファイルなので対象外
  list="$(find "${dist}" -path "${dist}/assets" -prune -o -type f -name '*.html' -print)" \
    || { echo "エラー: dist の走査（HTML 列挙）に失敗した" >&2; return 1; }
  # 読み取り前にファイルごと 8 MiB・合計 256 MiB の上限を見る（廃止した置換スクリプトと同値）。超過は検査を中止する
  rc=0
  printf '%s\n' "${list}" | python3 -I -B -c '
import os, sys
total = 0
for line in sys.stdin.read().split("\n"):
    if not line:
        continue
    size = os.lstat(line).st_size
    total += size
    if size > 8 * 1024 * 1024 or total > 256 * 1024 * 1024:
        sys.exit(1)
' || rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    echo "エラー: dist の HTML がサイズ上限（1 件 8 MiB・合計 256 MiB）を超える、または走査に失敗した" >&2
    return 1
  fi
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    rel="${f#"${dist}"/}"
    rc=0; grep -qF -- 'class="docs-header"' "${f}" || rc=$?
    [[ "${rc}" -le 1 ]] || { echo "エラー: ${rel} の検査（grep）が失敗した（exit ${rc}）" >&2; return 1; }
    has_chrome=$(( rc == 0 ? 1 : 0 ))
    if [[ "${has_chrome}" -eq 0 ]]; then
      case "${rel}" in
        index.html|404.html) echo "エラー: ${rel} にサイトのヘッダー（class=\"docs-header\"）が無い" >&2; return 1 ;;
      esac
      # リダイレクト案内はサイトのクロームを持たないため対象外。ただし refresh の文字列がどこかにあるだけでは
      # 免除しない。上流 redirect.rs の生成物と同じ形（head に meta refresh だけ・body は案内の <p> 1 つ）に
      # ファイル全体が一致するときに限る。それ以外の chrome なしページは fail-closed
      rc=0
      python3 -I -B -c '
import re, sys
from pathlib import Path
try:
    t = Path(sys.argv[1]).read_text(encoding="utf-8")
except (OSError, ValueError):
    sys.exit(3)
shape = (
    r"\s*<!DOCTYPE html>\s*<html(?: lang=\"[A-Za-z0-9-]{1,35}\")?>\s*<head>"
    r"(?:<meta charset=\"utf-8\">)?"
    r"<meta http-equiv=\"refresh\" content=\"[^\"<>]*\">"
    r"(?:<link rel=\"canonical\" href=\"[^\"<>]*\">)?"
    r"(?:<meta name=\"robots\" content=\"[^\"<>]*\">)?"
    r"(?:<title>[^<>]*</title>)?"
    r"</head>\s*<body>\s*<p>[^<>]*(?:<a href=\"[^\"<>]*\">[^<>]*</a>)?</p>\s*</body>\s*</html>\s*"
)
sys.exit(0 if re.fullmatch(shape, t) else 1)
' "${f}" || rc=$?
      [[ "${rc}" -le 1 ]] || { echo "エラー: ${rel} の検査（リダイレクト判定）が失敗した（exit ${rc}）" >&2; return 1; }
      if [[ "${rc}" -eq 0 ]]; then continue; fi
    fi
    # 帰属表記は `<footer class="docs-footer">` の中にちょうど 1 件あることを要求する（本文の同じ並びでは満たさない）。
    # python3 の終了コード: 0=一致、1=フッターが 1 つでない・並びが 1 件でない、それ以外=検査自体の失敗。
    rc=0
    SGP_PAT="${pat}" SGP_SCRIPTS="${SCRIPT_DIR}" python3 -I -B -c '
import os, re, sys
from pathlib import Path
# 末尾に足す: 先頭だと対象リポジトリ由来の同名ファイルより先にスキル側が読まれるが、標準ライブラリを隠せない位置に置く
sys.path.append(os.environ["SGP_SCRIPTS"])
from _common import read_bounded_text
# 読み取り上限は上の事前検査（ファイルごと 8 MiB）と同値。超過・UTF-8 不正は検査自体の失敗（exit 3）
try:
    t = read_bounded_text(Path(sys.argv[1]), 8 * 1024 * 1024)
except (OSError, ValueError):
    sys.exit(3)
foots = re.findall(r"<footer class=\"docs-footer\">.*?</footer>", t, re.S)
if len(foots) != 1:
    sys.exit(1)
sys.exit(0 if len(re.findall(os.environ["SGP_PAT"], foots[0])) == 1 else 1)
' "${f}" || rc=$?
    if [[ "${rc}" -eq 1 ]]; then
      echo "エラー: ${rel} のフッター（docs-footer）に帰属表記（Built with … docs-site と MIT / Apache-2.0 のライセンスリンク）がちょうど 1 件ない" >&2
      return 1
    fi
    if [[ "${rc}" -eq 3 ]]; then
      echo "エラー: ${rel} を上限内の UTF-8 として読めない（検査を中止）" >&2
      return 1
    fi
    [[ "${rc}" -eq 0 ]] || { echo "エラー: ${rel} の検査が失敗した（exit ${rc}）" >&2; return 1; }
    n=$(( n + 1 ))
  done <<< "${list}"
  echo "verify ok: HTML ${n} 件に帰属表記あり" >&2
}
# <<< verify_attribution

# ---- 生成（リンク検査は fail-closed。1 件でも壊れていれば何も書かず非 0）
step "サイトを生成"
"${INSTALL_ROOT}/bin/docs-site" --root "${ROOT}" --out "${OUT}" --no-page-sections

# ---- 最小 verify（空サイト・アセット欠落を黙って公開しない。-s で 0 バイトも検出）
step "verify"
for f in index.html 404.html assets/site.css assets/site.js assets/search-index.json; do
  test -s "${OUT}/${f}" || { echo "エラー: ${f} が無い、または空" >&2; exit 1; }
done
verify_attribution "${OUT}" || exit 1

step "完了: ${OUT}"
