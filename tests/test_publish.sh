#!/usr/bin/env bash
# Release publisher tests, with a fake gh. Run from anywhere: bash tests/test_publish.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH="$ROOT/scripts/publish-release.sh"
FAILS=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILS=$((FAILS + 1)); }
check() { # check DESC CMD...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}

# The fake gh goes first on PATH. The script's own temp dirs land under $WORK too.
mkdir -p "$WORK/bin" "$WORK/tmp"
cp "$ROOT/tests/fake-gh.sh" "$WORK/bin/gh"
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"
export TMPDIR="$WORK/tmp"
export GITHUB_REPOSITORY="acme/router"
TAG="v9.9.9"
ZIP="model-router.zip"
SUM="model-router.zip.sha256"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# make_dist DIR VERSION: writes the built files for a fake build.
make_dist() {
  mkdir -p "$1"
  printf 'zip-%s' "$2" > "$1/$ZIP"
  printf '%s  %s\n' "$(sha_of "$1/$ZIP")" "$ZIP" > "$1/$SUM"
}

# new_case VERSION: fresh fake release state and a dist folder holding VERSION.
CASE=""
new_case() {
  CASE="$(mktemp -d "$WORK/case.XXXXXX")"
  export FAKE_GH_STATE="$CASE/state"
  export MR_DIST_DIR="$CASE/dist"
  mkdir -p "$FAKE_GH_STATE"
  : > "$FAKE_GH_STATE/tag.$TAG"   # the git tag exists
  make_dist "$MR_DIST_DIR" "$1"
}

# seed_release VERSION: a release that already holds both assets built as VERSION.
seed_release() {
  local d="$CASE/seed"
  rm -rf "$d"
  make_dist "$d" "$1"
  gh release create "$TAG" --verify-tag --title "$TAG" --notes seed >/dev/null
  gh release upload "$TAG" "$d/$ZIP" "$d/$SUM" >/dev/null
}

asset_file() { # NAME -> path of the stored data, or empty
  local d
  for d in "$FAKE_GH_STATE/release.$TAG"/assets/*; do
    [ -d "$d" ] || continue
    if [ "$(cat "$d/name")" = "$1" ]; then echo "$d/data"; return 0; fi
  done
  return 0
}
set_state() { # NAME STATE: change the state of an asset in the fake release
  printf '%s' "$2" > "$(dirname "$(asset_file "$1")")/state"
}
has_asset() { [ -n "$(asset_file "$1")" ]; }
asset_text() { cat "$(asset_file "$1")"; }
asset_names() {
  local d
  for d in "$FAKE_GH_STATE/release.$TAG"/assets/*; do
    [ -d "$d" ] && cat "$d/name" && echo
  done | sort | tr '\n' ' '
}
reset_calls() { : > "$FAKE_GH_STATE/calls.log"; }
mutating_calls() {
  grep -cE '^(release (create|upload|delete-asset)|api -X PATCH)' "$FAKE_GH_STATE/calls.log"
}

OUT=""
RC=0
run_publish() {
  reset_calls
  OUT="$("$PUBLISH" "$TAG" "$@" 2>&1)"
  RC=$?
}
release_exists_in_fake() { [ -d "$FAKE_GH_STATE/release.$TAG" ]; }
no_gh_calls() { [ ! -s "$FAKE_GH_STATE/calls.log" ]; }
no_temp_leftovers() { [ -z "$(find "$WORK/tmp" -mindepth 1 -print -quit)" ]; }
out_has() { grep -qF -- "$1" <<<"$OUT"; }

echo "[new release]"
new_case v2
run_publish
check "exits 0" test "$RC" -eq 0
check "release was created with --verify-tag" grep -q -- '--verify-tag' "$FAKE_GH_STATE/calls.log"
check "zip uploaded" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum uploaded" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"
check "no temp dirs left by the script" no_temp_leftovers

echo "[rerun with nothing to do]"
run_publish
check "exits 0" test "$RC" -eq 0
check "no state-changing gh calls" test "$(mutating_calls)" -eq 0
check "reports both skipped" out_has "0 uploaded, 0 replaced, 2 already correct"
check "still exactly the two assets" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[only the zip is present]"
new_case v2
seed_release v2
# remove the checksum asset from the fake release
rm -rf "$(dirname "$(asset_file "$SUM")")"
run_publish
check "exits 0" test "$RC" -eq 0
check "checksum uploaded" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"
check "zip was not uploaded again" bash -c "! grep -q 'release upload.*$ZIP\$' '$FAKE_GH_STATE/calls.log'"
check "exactly one upload call" test "$(grep -c '^release upload' "$FAKE_GH_STATE/calls.log")" -eq 1

echo "[new release, checksum upload fails, then a retry]"
new_case v2
FAKE_FAIL_UPLOAD="$SUM" run_publish
check "exits non-zero" test "$RC" -ne 0
check "zip is on the release" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum is not on the release" bash -c "! test -n '$(asset_file "$SUM")'"
check "message names the checksum and the state" bash -c "grep -q 'upload of $SUM failed' <<<\"\$1\" && grep -q 'is not on release' <<<\"\$1\"" _ "$OUT"
run_publish
check "retry exits 0" test "$RC" -eq 0
check "retry uploads only the checksum" test "$(grep -c '^release upload' "$FAKE_GH_STATE/calls.log")" -eq 1
check "retry leaves both assets correct" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"

echo "[different asset without --replace]"
new_case v2
seed_release v1
run_publish
check "exits non-zero" test "$RC" -ne 0
check "message points at --replace" out_has "--replace"
check "no state-changing gh calls" test "$(mutating_calls)" -eq 0
check "old zip untouched" test "$(asset_text "$ZIP")" = "zip-v1"
check "old checksum untouched" test "$(cut -d' ' -f1 "$(asset_file "$SUM")")" = "$(sha_of "$CASE/seed/$ZIP")"

echo "[only the checksum differs, zip is missing: still nothing changes without --replace]"
new_case v2
seed_release v1
rm -rf "$(dirname "$(asset_file "$ZIP")")"
run_publish
check "exits non-zero" test "$RC" -ne 0
check "release untouched (no zip uploaded)" test "$(mutating_calls)" -eq 0

echo "[--replace succeeds]"
new_case v2
seed_release v1
run_publish --replace
check "exits 0" test "$RC" -eq 0
check "zip now has the new content" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum now has the new content" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"
check "no .new assets left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "
check "replaced via PATCH rename" grep -q '^api -X PATCH repos/acme/router/releases/assets/' "$FAKE_GH_STATE/calls.log"
check "reports 2 replaced" out_has "2 replaced"
run_publish --replace
check "a second --replace run is a no-op" test "$(mutating_calls)" -eq 0
check "no temp dirs left by the script" no_temp_leftovers

echo "[--replace, upload of the .new asset fails]"
new_case v2
seed_release v1
FAKE_FAIL_UPLOAD="$ZIP.new" run_publish --replace
check "exits non-zero" test "$RC" -ne 0
check "old zip still on the release" test "$(asset_text "$ZIP")" = "zip-v1"
check "old checksum still on the release" test "$(cut -d' ' -f1 "$(asset_file "$SUM")")" = "$(sha_of "$CASE/seed/$ZIP")"
check "no .new asset left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "
check "message says the old asset is untouched" out_has "old $ZIP is untouched"
check "nothing was deleted" bash -c "! grep -q '^release delete-asset' '$FAKE_GH_STATE/calls.log'"

echo "[--replace, delete succeeds but rename fails]"
new_case v2
seed_release v1
FAKE_FAIL_RENAME="$ZIP" run_publish --replace
check "exits non-zero" test "$RC" -ne 0
check "old zip is gone" bash -c "! test -n '$(asset_file "$ZIP")'"
check ".new asset holds the new content" test "$(asset_text "$ZIP.new")" = "zip-v2"
check "message tells how to finish" out_has "gh api -X PATCH repos/acme/router/releases/assets/"
check "message names the state" out_has "Release $TAG now has no $ZIP"
run_publish --replace
check "re-run with --replace finishes the job" test "$RC" -eq 0
check "zip renamed into place" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum replaced" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"
check "no .new assets left after recovery" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[--replace, delete of the old asset fails]"
new_case v2
seed_release v1
FAKE_FAIL_DELETE="$ZIP" run_publish --replace
check "exits non-zero" test "$RC" -ne 0
check "old zip still there" test "$(asset_text "$ZIP")" = "zip-v1"
check "verified .new is there" test "$(asset_text "$ZIP.new")" = "zip-v2"
run_publish --replace
check "re-run finishes the job" test "$RC" -eq 0
check "zip has the new content" test "$(asset_text "$ZIP")" = "zip-v2"
check "no .new assets left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[stale .new next to a correct asset]"
new_case v2
seed_release v2
printf 'junk' > "$CASE/$ZIP.new"
gh release upload "$TAG" "$CASE/$ZIP.new" >/dev/null
run_publish
check "exits 0" test "$RC" -eq 0
check "leftover .new removed" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[zip missing and a stale .new on the release]"
new_case v2
seed_release v2
rm -rf "$(dirname "$(asset_file "$ZIP")")"
printf 'junk' > "$CASE/$ZIP.new"
gh release upload "$TAG" "$CASE/$ZIP.new" >/dev/null
run_publish
check "exits 0" test "$RC" -eq 0
check "zip uploaded fresh" test "$(asset_text "$ZIP")" = "zip-v2"
check "stale .new removed" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[dry run]"
new_case v2
run_publish --dry-run
check "dry run on a new release exits 0" test "$RC" -eq 0
check "dry run makes no state-changing calls" test "$(mutating_calls)" -eq 0
check "dry run says what it would do" out_has "would: create release"
seed_release v1
run_publish --replace --dry-run
check "dry run with --replace exits 0" test "$RC" -eq 0
check "dry run with --replace makes no state-changing calls" test "$(mutating_calls)" -eq 0
check "dry run leaves the old zip" test "$(asset_text "$ZIP")" = "zip-v1"

echo "[create fails]"
new_case v2
FAKE_FAIL_CREATE=1 run_publish
check "exits non-zero" test "$RC" -ne 0
check "message says the release does not exist and nothing was uploaded" out_has "The release does not exist and nothing was uploaded"
check "no release was created" bash -c "! test -d '$FAKE_GH_STATE/release.$TAG'"
check "nothing was uploaded" bash -c "! grep -q '^release upload' '$FAKE_GH_STATE/calls.log'"
run_publish
check "a retry creates everything" test "$RC" -eq 0

echo "[the tag does not exist]"
new_case v2
rm -f "$FAKE_GH_STATE/tag.$TAG"
run_publish
check "exits non-zero" test "$RC" -ne 0
check "no release was created" bash -c "! test -d '$FAKE_GH_STATE/release.$TAG'"
check "message tells to make sure the tag exists" out_has "Make sure the tag exists"
check "nothing was uploaded" bash -c "! grep -q '^release upload' '$FAKE_GH_STATE/calls.log'"

echo "[download for comparison fails, without --replace]"
new_case v2
seed_release v2
FAKE_FAIL_DOWNLOAD="$ZIP" run_publish
check "exits non-zero" test "$RC" -ne 0
check "message says it could not download to compare" out_has "could not download existing $ZIP"
check "no state-changing gh calls" test "$(mutating_calls)" -eq 0
check "assets untouched" test "$(asset_text "$ZIP")" = "zip-v2"

echo "[download for comparison fails, with --replace]"
new_case v2
seed_release v2
FAKE_FAIL_DOWNLOAD_NTH="$ZIP:1" run_publish --replace
check "exits 0" test "$RC" -eq 0
check "log says it treats the asset as different" out_has "treating it as different"
check "zip was replaced through .new" grep -q "^release upload $TAG .*$ZIP.new" "$FAKE_GH_STATE/calls.log"
check "zip has the right content" test "$(asset_text "$ZIP")" = "zip-v2"
check "no .new assets left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[broken starter asset, without --replace]"
new_case v2
seed_release v2
set_state "$ZIP" starter
run_publish
check "exits 0" test "$RC" -eq 0
check "log says the broken asset was removed" out_has "removing broken $ZIP (state 'starter')"
check "broken asset was deleted" grep -q "^release delete-asset $TAG $ZIP " "$FAKE_GH_STATE/calls.log"
check "zip uploaded fresh, in the uploaded state" test "$(asset_text "$ZIP")" = "zip-v2"
check "the checksum asset was left alone" test "$(grep -c "^release delete-asset" "$FAKE_GH_STATE/calls.log")" -eq 1
check "no .new or PATCH involved" bash -c "! grep -qE 'PATCH|\.new' '$FAKE_GH_STATE/calls.log'"
check "exactly the two assets" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "
run_publish
check "a second run is a no-op" test "$(mutating_calls)" -eq 0

echo "[broken starter asset, with --replace]"
new_case v2
seed_release v1
set_state "$ZIP" starter
set_state "$SUM" starter
run_publish --replace
check "exits 0" test "$RC" -eq 0
check "both broken assets were removed and uploaded fresh" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum is right" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"
check "no rename was needed" bash -c "! grep -q PATCH '$FAKE_GH_STATE/calls.log'"
check "exactly the two assets" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[broken starter asset next to a differing good asset, without --replace]"
new_case v2
seed_release v1
set_state "$SUM" starter
run_publish
check "exits non-zero because the zip differs" test "$RC" -ne 0
check "nothing was changed, the broken asset included" test "$(mutating_calls)" -eq 0

echo "[broken .new asset next to the old asset, with --replace]"
new_case v2
seed_release v1
printf 'junk' > "$CASE/$ZIP.new"
gh release upload "$TAG" "$CASE/$ZIP.new" >/dev/null
set_state "$ZIP.new" starter
run_publish --replace
check "exits 0" test "$RC" -eq 0
check "broken .new was removed and zip replaced" test "$(asset_text "$ZIP")" = "zip-v2"
check "no .new assets left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[upload fails midway and leaves a starter asset]"
new_case v2
FAKE_FAIL_UPLOAD_PARTIAL="$SUM" run_publish
check "exits non-zero" test "$RC" -ne 0
check "message names the broken asset and how to recover" out_has "left a broken $SUM (state 'starter')"
run_publish
check "retry exits 0" test "$RC" -eq 0
check "retry deleted the broken asset" out_has "removing broken $SUM"
check "checksum is right now" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"

echo "[broken starter asset, dry run]"
new_case v2
seed_release v2
set_state "$ZIP" starter
run_publish --dry-run
check "exits 0" test "$RC" -eq 0
check "says what it would do" out_has "would: delete broken $ZIP"
check "says it would upload" out_has "would: upload $ZIP"
check "no state-changing gh calls" test "$(mutating_calls)" -eq 0

echo "[--replace, check after the rename fails]"
new_case v2
seed_release v1
FAKE_FAIL_DOWNLOAD_NTH="$ZIP:2" run_publish --replace
check "exits non-zero" test "$RC" -ne 0
check "message says it could not verify the renamed asset" out_has "could not download $ZIP to verify it"
check "the zip on the release has the new content" test "$(asset_text "$ZIP")" = "zip-v2"
run_publish --replace
check "re-run exits 0" test "$RC" -eq 0
check "re-run leaves the right assets" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[interrupted rename: the check after finishing the rename fails]"
new_case v2
seed_release v1
FAKE_FAIL_RENAME="$ZIP" run_publish --replace
check "first run fails at the rename" test "$RC" -ne 0
FAKE_FAIL_DOWNLOAD_NTH="$ZIP:1" run_publish --replace
check "exits non-zero when the check fails" test "$RC" -ne 0
check "message says it could not verify" out_has "could not download $ZIP to verify it"
check "the rename itself was done" test "$(asset_text "$ZIP")" = "zip-v2"
run_publish --replace
check "re-run exits 0" test "$RC" -eq 0
check "no .new assets left" test "$(asset_names)" = "model-router.zip model-router.zip.sha256 "

echo "[interrupted rename: the finished rename is verified by download]"
new_case v2
seed_release v1
FAKE_FAIL_RENAME="$ZIP" run_publish --replace
run_publish --replace
check "recovery run exits 0" test "$RC" -eq 0
check "zip downloaded after the rename to verify it" bash -c "grep -c '^release download $TAG .*--pattern $ZIP ' '$FAKE_GH_STATE/calls.log' | grep -qv '^0$'"

echo "[zip replaced, then the checksum replace fails]"
new_case v2
seed_release v1
FAKE_FAIL_UPLOAD="$SUM.new" run_publish --replace
check "exits non-zero" test "$RC" -ne 0
check "zip on the release is the new one" test "$(asset_text "$ZIP")" = "zip-v2"
check "checksum on the release is still the old one" test "$(cut -d' ' -f1 "$(asset_file "$SUM")")" = "$(sha_of "$CASE/seed/$ZIP")"
check "message says the release has the new zip with the old checksum" out_has "now has the new $ZIP with the old $SUM"
check "message says how to finish" out_has "re-run with --replace"
run_publish --replace
check "re-run with --replace finishes" test "$RC" -eq 0
check "checksum now matches the new zip" cmp -s "$MR_DIST_DIR/$SUM" "$(asset_file "$SUM")"

echo "[invalid TAG and GITHUB_REPOSITORY]"
new_case v2
# shellcheck disable=SC2016  # the $(...) values are literal test inputs, not expansions
for t in v1.2 1.2.3 v1.2.3-rc1 "v1.2.3 " "v1.2.x" 'v1.2.3;id' 'v1.2.3$(id)' "vv1.2.3"; do
  reset_calls
  "$PUBLISH" "$t" >/dev/null 2>&1; rc=$?
  check "TAG '$t' is rejected with exit 2" test "$rc" -eq 2
  check "TAG '$t' made no gh call" no_gh_calls
done
# shellcheck disable=SC2016
for r in "acme" "acme/" "/router" "a/b/c" "acme/rou ter" 'acme/router;id' 'acme/$(id)' "../router" "acme/.." "./router"; do
  reset_calls
  GITHUB_REPOSITORY="$r" "$PUBLISH" "$TAG" >/dev/null 2>&1; rc=$?
  check "GITHUB_REPOSITORY '$r' is rejected with exit 2" test "$rc" -eq 2
  check "GITHUB_REPOSITORY '$r' made no gh call" no_gh_calls
done
reset_calls
GITHUB_REPOSITORY="Acme_x.y/router-2.0" "$PUBLISH" "$TAG" --dry-run >/dev/null 2>&1
check "a valid owner/repo with . _ - is accepted" test "$?" -eq 0

echo "[workflow: old tags, pins and checkout settings]"
WF="$ROOT/.github/workflows/release.yml"
STEP="$WORK/old-tag-step.sh"
# Extract the run block of the early "Reject tags older" step, so the real code is tested.
awk '
  /- name: Reject tags older than v1\.0\.3/ { f = 1; next }
  f && /^      - / { exit }
  f && /run: \|/ { r = 1; next }
  f && r { sub(/^          /, ""); print }
' "$WF" > "$STEP"
check "found the old-tag step in the workflow" test -s "$STEP"
check "the step comes before the checkout" bash -c "[ \$(grep -n 'Reject tags older' '$WF' | cut -d: -f1) -lt \$(grep -n 'actions/checkout' '$WF' | cut -d: -f1) ]"
tag_gate() { TAG="$1" bash "$STEP" 2>&1; }
for t in v1.0.2 v1.0.0 v0.9.9 v0.99.99 v1.0.02 v0.0.1; do
  out="$(tag_gate "$t")"; rc=$?
  check "old tag $t is rejected" test "$rc" -ne 0
  check "old tag $t gets the clear message" grep -qF "Releases before v1.0.3 were published by an earlier workflow; this workflow supports v1.0.3 and later." <<<"$out"
done
for t in v1.0.3 v1.0.4 v1.0.10 v1.0.100 v1.1.0 v1.10.0 v2.0.0 v10.0.0 v1.0.03 v1.0.08 v1.2.0; do
  out="$(tag_gate "$t")"; rc=$?
  check "tag $t is accepted (compared as numbers, not strings)" test "$rc" -eq 0
done
for t in main v1.0 v1.0.3-rc1 "v1.0.3;id" ""; do
  tag_gate "$t" >/dev/null; rc=$?
  check "non-version tag '$t' is rejected" test "$rc" -ne 0
done
check "dispatch input example is v1.0.3" grep -q 'for example v1.0.3)' "$WF"
check "checkout does not persist credentials" grep -q 'persist-credentials: false' "$WF"
check "pyyaml is pinned to an exact version" grep -qE 'pip install --quiet pyyaml==[0-9]+\.[0-9]+\.[0-9]+' "$WF"
check "the release run uses the publish script and tests" bash -c "grep -q 'tests/test_publish.sh' '$WF' && grep -q 'scripts/publish-release.sh' '$WF'"

echo "[bad input]"
new_case v2
check "no tag fails" bash -c "! '$PUBLISH' >/dev/null 2>&1"
check "unknown option fails" bash -c "! '$PUBLISH' $TAG --nope >/dev/null 2>&1"
check "missing GITHUB_REPOSITORY fails" bash -c "! env -u GITHUB_REPOSITORY '$PUBLISH' $TAG >/dev/null 2>&1"
printf 'tampered' > "$MR_DIST_DIR/$ZIP"
run_publish
check "a checksum that does not match the zip fails" test "$RC" -ne 0
check "and the release is not touched" test "$(mutating_calls)" -eq 0
rm -f "$MR_DIST_DIR/$SUM"
run_publish
check "a missing built file fails" test "$RC" -ne 0
check "no temp dirs left under the work dir by the script" no_temp_leftovers

echo
if [ "$FAILS" -eq 0 ]; then echo "All tests passed."; else echo "$FAILS test(s) failed."; exit 1; fi
