#!/usr/bin/env bash
# Publish the release assets built into dist/ to a GitHub release, safely.
#
# Usage: scripts/publish-release.sh TAG [--replace] [--dry-run]
#
# Reads dist/model-router.zip and dist/model-router.zip.sha256 (override the
# folder with MR_DIST_DIR) and uses the gh CLI with GITHUB_REPOSITORY
# (owner/repo). Re-running is always safe:
#   - the release is created (with --verify-tag) only if it doesn't exist;
#   - an asset that is missing is uploaded and then checked by downloading it;
#   - an asset whose state is not "uploaded" (for example "starter", left by a
#     failed upload) was never a valid published file: it is deleted and
#     uploaded fresh, with or without --replace;
#   - an asset that is present is downloaded and compared by sha256 with the
#     freshly built file: equal means skip, different means fail, unless
#     --replace is given (with --replace, an asset that can't be downloaded
#     for the comparison counts as different);
#   - --replace uploads <name>.new, verifies it, deletes the old asset, then
#     renames <name>.new to <name>, so a failure at any step leaves the old or
#     the new asset on the release, never neither. A leftover <name>.new from
#     an interrupted run is finished (and verified) or cleaned up on the next run.
# TAG must look like vMAJOR.MINOR.PATCH and GITHUB_REPOSITORY like owner/repo;
# both are checked before any gh call.
# Exit status is non-zero on any failure, and the message says what state the
# release is in.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${MR_DIST_DIR:-$ROOT/dist}"
ASSETS="model-router.zip model-router.zip.sha256"
NOTES="Download model-router.zip below and upload it as a custom skill in the Claude desktop app (also web and mobile). Verify it with model-router.zip.sha256. For Claude Code, Codex, Gemini CLI, Cursor and Copilot, see the README's Quick install. Details are in CHANGELOG.md."

usage() {
  cat <<USAGE
Usage: $0 TAG [--replace] [--dry-run]

  TAG        Release tag to publish (it must already exist as a git tag).
  --replace  Replace assets whose content differs from dist/ (safe replace:
             upload <name>.new, verify, delete the old asset, rename).
  --dry-run  Read the release, print what would change, and change nothing.

Needs: gh (authenticated), GITHUB_REPOSITORY=owner/repo, and the built files
dist/model-router.zip and dist/model-router.zip.sha256.
USAGE
}

TAG=""
REPLACE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --replace) REPLACE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2 ;;
    *)
      [ -z "$TAG" ] || { echo "error: only one tag may be given" >&2; exit 2; }
      TAG="$1"; shift ;;
  esac
done
[ -n "$TAG" ] || { usage >&2; exit 2; }

# Validate input before any gh call (patterns kept in variables for Bash 3.2).
tag_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
if ! [[ $TAG =~ $tag_re ]]; then
  echo "error: TAG must look like v1.2.3 (got '$TAG')" >&2
  exit 2
fi
REPO="${GITHUB_REPOSITORY:-}"
repo_re='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
if ! [[ $REPO =~ $repo_re ]]; then
  echo "error: GITHUB_REPOSITORY must be set to owner/repo using only letters, digits, '.', '_' and '-' (got '$REPO')" >&2
  exit 2
fi
case "/$REPO/" in
  /./*|/../*|*/./|*/../)
    echo "error: GITHUB_REPOSITORY must not contain a '.' or '..' part (got '$REPO')" >&2
    exit 2 ;;
esac
command -v gh >/dev/null 2>&1 || { echo "error: gh is not installed" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/publish-release.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
ERRF="$WORK/gh-stderr"

log() { echo "$*"; }
# POSTSCRIPT, when set, is printed after every error message (see the zip/checksum note below).
POSTSCRIPT=""
die() {
  echo "error: $*" >&2
  if [ -n "$POSTSCRIPT" ]; then echo "$POSTSCRIPT" >&2; fi
  exit 1
}

# sha256_of FILE: prints the hex digest (sha256sum on Linux, shasum on macOS).
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# gh_show_err: prints the last gh stderr, indented.
gh_show_err() {
  if [ -s "$ERRF" ]; then sed 's/^/    gh: /' "$ERRF" >&2; fi
}

# release_exists: 0 = exists, 1 = not found; anything else is a hard failure.
release_exists() {
  if gh release view "$TAG" -R "$REPO" >/dev/null 2>"$ERRF"; then
    return 0
  fi
  if grep -qi "release not found" "$ERRF"; then
    return 1
  fi
  gh_show_err
  die "could not read release $TAG in $REPO, so its state is unknown. Nothing was changed by this run. Check gh authentication and network, then re-run."
}

# refresh_assets: loads "<numeric id><TAB><name><TAB><state>" lines into ASSET_LIST.
ASSET_LIST=""
refresh_assets() {
  if ! ASSET_LIST="$(gh api "repos/$REPO/releases/tags/$TAG" \
      --jq '.assets[] | "\(.id)\t\(.name)\t\(.state)"' 2>"$ERRF")"; then
    gh_show_err
    die "could not list the assets of release $TAG, so its state is unknown. Re-run to retry; the script is safe to repeat."
  fi
}

# asset_id NAME: prints the id of the fully uploaded asset with that exact
# name, or nothing. An asset in any other state does not count as present.
asset_id() {
  printf '%s\n' "$ASSET_LIST" | awk -F '\t' -v n="$1" '$2 == n && $3 == "uploaded" { print $1; exit }'
}

# asset_any_id NAME: like asset_id, but for an asset in any state.
asset_any_id() {
  printf '%s\n' "$ASSET_LIST" | awk -F '\t' -v n="$1" '$2 == n { print $1; exit }'
}

# asset_state NAME: prints the state of the asset with that name, or nothing.
asset_state() {
  printf '%s\n' "$ASSET_LIST" | awk -F '\t' -v n="$1" '$2 == n { print $3; exit }'
}

# remote_sha NAME: downloads the asset and prints its sha256. Returns 1 on failure.
remote_sha() {
  local name="$1" d
  d="$(mktemp -d "$WORK/dl.XXXXXX")" || return 1
  if ! gh release download "$TAG" -R "$REPO" --pattern "$name" --dir "$d" --clobber >/dev/null 2>"$ERRF"; then
    return 1
  fi
  [ -f "$d/$name" ] || return 1
  sha256_of "$d/$name"
}

# mutate DESC CMD...: runs a state-changing gh command, or only prints it with --dry-run.
mutate() {
  local desc="$1"; shift
  if [ "$DRY" -eq 1 ]; then
    log "would: $desc"
    return 0
  fi
  "$@" >/dev/null 2>"$ERRF"
}

# Local files must exist, and the checksum file must describe the zip.
for name in $ASSETS; do
  [ -f "$DIST/$name" ] || die "missing $DIST/$name. Build it first with ./install.sh claude-app and sha256sum. The release was not touched."
done
local_zip_sha="$(sha256_of "$DIST/model-router.zip")"
case "$(cut -d' ' -f1 "$DIST/model-router.zip.sha256" | head -1)" in
  "$local_zip_sha") ;;
  *) die "$DIST/model-router.zip.sha256 does not match $DIST/model-router.zip. The release was not touched." ;;
esac

# ---- release ----------------------------------------------------------------
if release_exists; then
  log "release $TAG exists in $REPO"
  HAVE_RELEASE=1
else
  HAVE_RELEASE=0
  if [ "$DRY" -eq 1 ]; then
    log "would: create release $TAG in $REPO (--verify-tag)"
  else
    log "creating release $TAG in $REPO"
    if ! gh release create "$TAG" -R "$REPO" --verify-tag --title "$TAG" --notes "$NOTES" >/dev/null 2>"$ERRF"; then
      gh_show_err
      if release_exists; then
        log "release $TAG now exists (created elsewhere); continuing"
        HAVE_RELEASE=1
      else
        die "could not create release $TAG. The release does not exist and nothing was uploaded. Make sure the tag exists on GitHub, then re-run."
      fi
    else
      HAVE_RELEASE=1
    fi
  fi
fi

if [ "$HAVE_RELEASE" -eq 1 ]; then
  refresh_assets
else
  ASSET_LIST=""
fi

# ---- phase 1: detect conflicts before changing anything ---------------------
if [ "$REPLACE" -eq 0 ]; then
  for name in $ASSETS; do
    id="$(asset_id "$name")"
    [ -n "$id" ] || continue
    rsha="$(remote_sha "$name")" || {
      gh_show_err
      die "could not download existing $name from release $TAG to compare it. Nothing was changed. Re-run to retry."
    }
    lsha="$(sha256_of "$DIST/$name")"
    if [ "$rsha" != "$lsha" ]; then
      die "$name on release $TAG differs from the file just built (release sha256 $rsha, built sha256 $lsha). Nothing was changed; the release keeps its existing assets. Re-run with --replace to replace it safely, or investigate why the build differs."
    fi
  done
fi

# ---- broken assets ----------------------------------------------------------
# An asset of ours whose state is not "uploaded" (for example "starter" after a
# failed upload) was never a valid published file. Delete it so a fresh upload
# can replace it, with or without --replace. Other assets are never touched.
purge_broken() {
  local base name state
  for base in $ASSETS; do
    for name in "$base" "$base.new"; do
      state="$(asset_state "$name")"
      if [ -z "$state" ] || [ "$state" = "uploaded" ]; then continue; fi
      log "removing broken $name (state '$state'); it was never a valid published file"
      if ! mutate "delete broken $name from release $TAG" gh release delete-asset "$TAG" "$name" -R "$REPO" --yes; then
        gh_show_err
        die "could not delete the broken $name (state '$state') on release $TAG. Nothing else was changed. Re-run to retry; the script is safe to repeat."
      fi
      if [ "$DRY" -eq 1 ]; then
        ASSET_LIST="$(printf '%s\n' "$ASSET_LIST" | awk -F '\t' -v n="$name" '$2 != n')"
      fi
    done
  done
  if [ "$DRY" -eq 0 ]; then refresh_assets; fi
}
if [ "$HAVE_RELEASE" -eq 1 ]; then purge_broken; fi

# ---- phase 2: publish each asset --------------------------------------------
UPLOADED=0
SKIPPED=0
REPLACED=0

# upload_verified NAME: uploads dist/NAME (as NAME) and verifies it by downloading.
UP_N=0
upload_verified() {
  local name="$1" file="$2" lsha="$3" d rsha
  UP_N=$((UP_N + 1))
  d="$WORK/up.$UP_N"
  mkdir -p "$d"
  cp "$file" "$d/$name"
  log "uploading $name"
  if ! mutate "upload $name to release $TAG" gh release upload "$TAG" "$d/$name" -R "$REPO"; then
    gh_show_err
    return 1
  fi
  [ "$DRY" -eq 1 ] && return 0
  refresh_assets
  rsha="$(remote_sha "$name")" || { gh_show_err; return 2; }
  [ "$rsha" = "$lsha" ] || return 3
  return 0
}

# fresh_upload NAME: for an asset that is not on the release.
fresh_upload() {
  local name="$1" file="$DIST/$1" lsha rc
  lsha="$(sha256_of "$file")"
  upload_verified "$name" "$file" "$lsha"
  rc=$?
  case "$rc" in
    0) UPLOADED=$((UPLOADED + 1)) ;;
    1)
      if [ "$DRY" -eq 0 ]; then refresh_assets; fi
      if [ -n "$(asset_id "$name")" ]; then
        die "upload of $name failed, and an asset with that name now exists on release $TAG (it may be incomplete). Re-run with --replace to replace it safely. Assets uploaded earlier in this run are still on the release."
      fi
      if [ -n "$(asset_any_id "$name")" ]; then
        die "upload of $name failed and left a broken $name (state '$(asset_state "$name")') on release $TAG. Re-run: the script deletes the broken asset and uploads it fresh. Assets uploaded earlier in this run are still on the release."
      fi
      die "upload of $name failed. $name is not on release $TAG. Assets uploaded earlier in this run are still there. Re-run to upload the rest; the script is safe to repeat."
      ;;
    2) die "uploaded $name but could not download it back to verify it. It is on release $TAG and unverified. Re-run to compare it; the script is safe to repeat." ;;
    *) die "uploaded $name but its sha256 on the release does not match the built file. The bad $name is on release $TAG. Re-run with --replace to replace it safely." ;;
  esac
}

# verify_renamed NAME LSHA: after a rename, re-list and download NAME and compare.
verify_renamed() {
  local name="$1" lsha="$2" nsha
  if [ "$DRY" -eq 1 ]; then return 0; fi
  refresh_assets
  nsha="$(remote_sha "$name")" || { gh_show_err; die "renamed $name.new to $name but could not download $name to verify it. Re-run to compare it; the script is safe to repeat."; }
  [ "$nsha" = "$lsha" ] || die "renamed $name.new to $name but the content on the release does not match the built file. Re-run with --replace."
}

# replace_asset NAME NEW_ID: safe replace of a differing asset.
replace_asset() {
  local name="$1" newid="$2" new="$1.new" file="$DIST/$1" lsha nsha rc
  lsha="$(sha256_of "$file")"

  # Step 1: have a verified <name>.new on the release.
  if [ -n "$newid" ]; then
    if nsha="$(remote_sha "$new")" && [ "$nsha" = "$lsha" ]; then
      log "$new already on the release with the right content; reusing it"
    else
      log "removing stale $new"
      if ! mutate "delete stale $new from release $TAG" gh release delete-asset "$TAG" "$new" -R "$REPO" --yes; then
        gh_show_err
        die "could not delete stale $new. The old $name is untouched on release $TAG (and so is the stale $new). Re-run with --replace to retry."
      fi
      newid=""
    fi
  fi
  if [ -z "$newid" ]; then
    upload_verified "$new" "$file" "$lsha"
    rc=$?
    case "$rc" in
      0) ;;
      1) die "upload of $new failed. The old $name is untouched on release $TAG. Re-run with --replace to retry." ;;
      2) die "uploaded $new but could not download it back to verify it. The old $name is untouched on release $TAG, and an unverified $new is also there. Re-run with --replace to retry." ;;
      *) die "uploaded $new but its sha256 does not match the built file. The old $name is untouched on release $TAG, and the bad $new is also there. Re-run with --replace to retry (it deletes the bad $new first)." ;;
    esac
    if [ "$DRY" -eq 0 ]; then newid="$(asset_id "$new")"; fi
    if [ "$DRY" -eq 0 ] && [ -z "$newid" ]; then
      die "uploaded $new but it is not listed on release $TAG. The old $name is untouched. Re-run with --replace to retry."
    fi
  fi

  # Step 2: delete the old asset (the verified new content is already on the release).
  log "deleting old $name"
  if ! mutate "delete old $name from release $TAG" gh release delete-asset "$TAG" "$name" -R "$REPO" --yes; then
    gh_show_err
    die "could not delete the old $name. Release $TAG still has the old $name (it may or may not have been removed) and the verified $new. Re-run with --replace to finish."
  fi

  # Step 3: rename <name>.new to <name>.
  log "renaming $new to $name"
  if ! mutate "rename $new to $name" gh api -X PATCH "repos/$REPO/releases/assets/${newid:-NEW_ID}" -f "name=$name"; then
    gh_show_err
    die "the old $name was deleted but renaming $new to $name failed. Release $TAG now has no $name; $new (asset id $newid) holds the verified new content. To finish, run: gh api -X PATCH repos/$REPO/releases/assets/$newid -f name=$name   or re-run: scripts/publish-release.sh $TAG --replace"
  fi
  verify_renamed "$name" "$lsha"
  REPLACED=$((REPLACED + 1))
}

publish_asset() {
  local name="$1" file="$DIST/$1" id newid lsha rsha
  id="$(asset_id "$name")"
  newid="$(asset_id "$name.new")"
  lsha="$(sha256_of "$file")"

  if [ -z "$id" ]; then
    if [ -n "$newid" ]; then
      # An earlier --replace run deleted the old asset and stopped before the rename.
      if rsha="$(remote_sha "$name.new")" && [ "$rsha" = "$lsha" ]; then
        log "$name is missing but $name.new holds the right content; finishing the rename"
        if ! mutate "rename $name.new to $name" gh api -X PATCH "repos/$REPO/releases/assets/$newid" -f "name=$name"; then
          gh_show_err
          die "renaming $name.new to $name failed. Release $TAG has no $name; $name.new (asset id $newid) holds the verified content. To finish, run: gh api -X PATCH repos/$REPO/releases/assets/$newid -f name=$name   or re-run this script."
        fi
        verify_renamed "$name" "$lsha"
        REPLACED=$((REPLACED + 1))
        return 0
      fi
      log "$name.new on the release is stale; uploading $name and removing it"
      fresh_upload "$name"
      if ! mutate "delete stale $name.new from release $TAG" gh release delete-asset "$TAG" "$name.new" -R "$REPO" --yes; then
        gh_show_err
        die "$name is now correct on release $TAG, but the stale $name.new could not be deleted. Delete it by hand or re-run to retry."
      fi
      return 0
    fi
    fresh_upload "$name"
    return 0
  fi

  # Present on the release: compare content.
  if ! rsha="$(remote_sha "$name")"; then
    gh_show_err
    if [ "$REPLACE" -eq 0 ]; then
      die "could not download existing $name from release $TAG to compare it. Nothing was changed for this asset. Re-run to retry, or use --replace to replace it safely."
    fi
    log "could not download existing $name to compare it; treating it as different and replacing it safely"
    replace_asset "$name" "$newid"
    return 0
  fi
  if [ "$rsha" = "$lsha" ]; then
    log "$name is already correct on release $TAG; skipping"
    SKIPPED=$((SKIPPED + 1))
    if [ -n "$newid" ]; then
      log "removing leftover $name.new"
      if ! mutate "delete leftover $name.new from release $TAG" gh release delete-asset "$TAG" "$name.new" -R "$REPO" --yes; then
        gh_show_err
        die "$name is correct on release $TAG, but a leftover $name.new could not be deleted. Delete it by hand or re-run to retry."
      fi
    fi
    return 0
  fi
  if [ "$REPLACE" -eq 0 ]; then
    die "$name on release $TAG differs from the file just built (release sha256 $rsha, built sha256 $lsha). It was not changed. Re-run with --replace to replace it safely."
  fi
  log "$name differs from the built file; replacing it safely"
  replace_asset "$name" "$newid"
}

for name in $ASSETS; do
  before="$REPLACED"
  publish_asset "$name"
  if [ "$name" = "model-router.zip" ] && [ "$REPLACED" -gt "$before" ]; then
    POSTSCRIPT="note: model-router.zip was replaced in this run but the checksum was not, so release $TAG now has the new model-router.zip with the old model-router.zip.sha256. To finish, re-run with --replace: scripts/publish-release.sh $TAG --replace"
  fi
done

if [ "$DRY" -eq 1 ]; then
  log "Dry run: nothing was changed."
else
  log "Release $TAG is up to date: $UPLOADED uploaded, $REPLACED replaced, $SKIPPED already correct."
fi
exit 0
