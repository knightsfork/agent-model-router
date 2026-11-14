#!/usr/bin/env bash
# Fake `gh` for tests/test_publish.sh. Release state lives in $FAKE_GH_STATE:
#   release.<tag>/assets/<id>/{name,data,state}, tag.<tag> (the git tags that
#   exist), next_id, calls.log (one line per call).
# An asset's state is "uploaded" unless a test writes something else (such as
# "starter") into its state file. A starter asset can't be downloaded.
# `release create --verify-tag` fails when tag.<tag> is missing; without it the
# fake creates the tag, like gh does.
# `api --jq EXPR` pipes the JSON through `jq -r EXPR` when jq is installed, so
# the script's own jq expressions are exercised. Without jq it prints
# "<id><TAB><name><TAB><state>" lines, which is what the script's expression
# produces.
# Failures are simulated with env vars that name an asset (or the new name):
#   FAKE_FAIL_CREATE=1, FAKE_FAIL_UPLOAD=<file name>, FAKE_FAIL_DOWNLOAD=<asset name>,
#   FAKE_FAIL_DOWNLOAD_NTH=<asset name>:<n> (only the n-th download of it fails),
#   FAKE_FAIL_DELETE=<asset name>, FAKE_FAIL_RENAME=<new name>,
#   FAKE_FAIL_UPLOAD_PARTIAL=<file name> (fails, but leaves a starter asset)
S="${FAKE_GH_STATE:?FAKE_GH_STATE is not set}"
mkdir -p "$S"
echo "$*" >> "$S/calls.log"

fail() { echo "$1" >&2; exit 1; }

[ $# -ge 2 ] || fail "fake gh: too few arguments"
if [ "$1" = "api" ]; then
  group="api"
  shift
else
  group="$1 $2"
  shift 2
fi

# Shared option parsing. Positional arguments end up in POS (one per line).
POS=""
PATTERN=""
DIR="."
METHOD="GET"
FIELD=""
JQ=""
VERIFY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -R|--repo|--title|--notes|--json) shift 2 ;;
    --jq) JQ="$2"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --dir|-D) DIR="$2"; shift 2 ;;
    -X) METHOD="$2"; shift 2 ;;
    -f) FIELD="$2"; shift 2 ;;
    --verify-tag) VERIFY=1; shift ;;
    --clobber|--yes|-y) shift ;;
    -*) fail "fake gh: unknown flag $1" ;;
    *) POS="$POS$1
"; shift ;;
  esac
done

pos() { printf '%s' "$POS" | sed -n "${1}p"; }

rel_dir() { echo "$S/release.$1"; }

# find_asset TAG NAME: prints the asset directory, or nothing.
find_asset() {
  local d n
  for d in "$(rel_dir "$1")"/assets/*; do
    [ -d "$d" ] || continue
    n="$(cat "$d/name")"
    if [ "$n" = "$2" ]; then echo "$d"; return 0; fi
  done
  return 0
}

new_id() {
  local n
  n="$(cat "$S/next_id" 2>/dev/null || echo 1000)"
  echo $((n + 1)) > "$S/next_id"
  echo "$n"
}

case "$group" in
  "release view")
    [ -d "$(rel_dir "$(pos 1)")" ] || fail "release not found"
    echo "title: $(pos 1)"
    ;;
  "release create")
    [ -z "${FAKE_FAIL_CREATE:-}" ] || fail "HTTP 500: create failed"
    t="$(pos 1)"
    [ ! -d "$(rel_dir "$t")" ] || fail "a release with the tag $t already exists"
    if [ ! -e "$S/tag.$t" ]; then
      [ "$VERIFY" -eq 0 ] || fail "tag $t not found in the repository"
      : > "$S/tag.$t"
    fi
    mkdir -p "$(rel_dir "$t")/assets"
    echo "https://example.invalid/releases/$t"
    ;;
  "release upload")
    t="$(pos 1)"
    [ -d "$(rel_dir "$t")" ] || fail "release not found"
    i=2
    while f="$(pos "$i")"; [ -n "$f" ]; do
      base="$(basename "$f")"
      [ -f "$f" ] || fail "no such file: $f"
      if [ "${FAKE_FAIL_UPLOAD_PARTIAL:-}" = "$base" ]; then
        id="$(new_id)"
        mkdir -p "$(rel_dir "$t")/assets/$id"
        printf '%s' "$base" > "$(rel_dir "$t")/assets/$id/name"
        printf 'starter' > "$(rel_dir "$t")/assets/$id/state"
        : > "$(rel_dir "$t")/assets/$id/data"
        fail "HTTP 500: upload of $base failed midway"
      fi
      [ "${FAKE_FAIL_UPLOAD:-}" != "$base" ] || fail "HTTP 500: upload of $base failed"
      [ -z "$(find_asset "$t" "$base")" ] || fail "a release asset named $base already exists"
      id="$(new_id)"
      mkdir -p "$(rel_dir "$t")/assets/$id"
      printf '%s' "$base" > "$(rel_dir "$t")/assets/$id/name"
      printf 'uploaded' > "$(rel_dir "$t")/assets/$id/state"
      cp "$f" "$(rel_dir "$t")/assets/$id/data"
      i=$((i + 1))
    done
    ;;
  "release download")
    t="$(pos 1)"
    [ -d "$(rel_dir "$t")" ] || fail "release not found"
    [ "${FAKE_FAIL_DOWNLOAD:-}" != "$PATTERN" ] || fail "HTTP 500: download failed"
    if [ "${FAKE_FAIL_DOWNLOAD_NTH:-}" != "" ] && [ "${FAKE_FAIL_DOWNLOAD_NTH%%:*}" = "$PATTERN" ]; then
      cnt="$(cat "$S/dl.$PATTERN" 2>/dev/null || echo 0)"
      cnt=$((cnt + 1))
      echo "$cnt" > "$S/dl.$PATTERN"
      [ "$cnt" -ne "${FAKE_FAIL_DOWNLOAD_NTH##*:}" ] || fail "HTTP 500: download failed (call $cnt)"
    fi
    a="$(find_asset "$t" "$PATTERN")"
    [ -n "$a" ] || fail "no assets match the file pattern"
    [ "$(cat "$a/state" 2>/dev/null || echo uploaded)" = "uploaded" ] || fail "HTTP 404: asset is not downloadable"
    mkdir -p "$DIR"
    cp "$a/data" "$DIR/$PATTERN"
    ;;
  "release delete-asset")
    t="$(pos 1)"
    n="$(pos 2)"
    [ "${FAKE_FAIL_DELETE:-}" != "$n" ] || fail "HTTP 500: delete failed"
    a="$(find_asset "$t" "$n")"
    [ -n "$a" ] || fail "asset under the name \"$n\" not found"
    rm -rf "$a"
    ;;
  "api")
    path="$(pos 1)"
    case "$METHOD:$path" in
      GET:repos/*/releases/tags/*)
        t="${path##*/releases/tags/}"
        [ -d "$(rel_dir "$t")" ] || fail "HTTP 404: Not Found"
        json='{"assets":['
        sep=""
        for d in "$(rel_dir "$t")"/assets/*; do
          [ -d "$d" ] || continue
          st="$(cat "$d/state" 2>/dev/null || echo uploaded)"
          json="$json$sep{\"id\":$(basename "$d"),\"name\":\"$(cat "$d/name")\",\"state\":\"$st\"}"
          sep=","
        done
        json="$json]}"
        if [ -z "$JQ" ]; then
          echo "$json"
        elif command -v jq >/dev/null 2>&1; then
          printf '%s' "$json" | jq -r "$JQ" || exit 1
        else
          # No jq: emulate the one expression the script uses.
          for d in "$(rel_dir "$t")"/assets/*; do
            [ -d "$d" ] || continue
            printf '%s\t%s\t%s\n' "$(basename "$d")" "$(cat "$d/name")" "$(cat "$d/state" 2>/dev/null || echo uploaded)"
          done
        fi
        ;;
      PATCH:repos/*/releases/assets/*)
        id="${path##*/releases/assets/}"
        newname="${FIELD#name=}"
        [ "${FAKE_FAIL_RENAME:-}" != "$newname" ] || fail "HTTP 500: rename failed"
        d=""
        for c in "$S"/release.*/assets/"$id"; do
          if [ -d "$c" ]; then d="$c"; fi
        done
        [ -n "$d" ] || fail "HTTP 404: Not Found"
        rd="$(dirname "$(dirname "$d")")"
        [ -z "$(find_asset "${rd#"$S"/release.}" "$newname")" ] || fail "HTTP 422: already_exists"
        printf '%s' "$newname" > "$d/name"
        ;;
      *) fail "fake gh: unsupported api call $METHOD $path" ;;
    esac
    ;;
  *) fail "fake gh: unsupported command $group" ;;
esac
