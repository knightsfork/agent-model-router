#!/usr/bin/env bash
# agent-model-router installer.
# Usage: ./install.sh <platform|all> [--project DIR] [--force] [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$ROOT/skills/model-router"
PLATFORMS="claude-code codex gemini-cli cursor copilot"

usage() {
  cat <<USAGE
Usage: $0 <platform|all> [--project DIR] [--force] [--dry-run]

Platforms: claude-code (alias: claude), codex, gemini-cli (alias: gemini),
           cursor, copilot, claude-app (alias: claude-desktop), or all.

  claude-app builds dist/model-router.zip in this repo to upload as a custom
  skill in the Claude apps. It writes nothing under \$HOME or --project, and
  "all" does not include it (all covers only tools with skill folders).

  --project DIR  Install into project paths under DIR instead of \$HOME.
  --force        Overwrite differing files (the old file is saved as
                 <file>.bak.<YYYYmmddHHMMSS>; existing backups are never overwritten).
  --dry-run      Print what would happen and change nothing.
USAGE
}

FORCE=0
DRY=0
PROJECT=""
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      [ $# -ge 2 ] || { echo "error: --project needs a directory" >&2; exit 2; }
      [ -n "$2" ] || { echo "error: --project needs a non-empty directory" >&2; exit 2; }
      PROJECT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2 ;;
    *)
      [ -z "$TARGET" ] || { echo "error: only one platform may be given" >&2; exit 2; }
      TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || { usage >&2; exit 2; }

case "$TARGET" in
  claude) TARGET="claude-code" ;;
  claude-desktop) TARGET="claude-app" ;;
  gemini) TARGET="gemini-cli" ;;
esac

# build_zip: builds dist/model-router.zip with a top-level model-router/ folder.
BUILD_TMP=""
cleanup_build() {
  if [ -n "$BUILD_TMP" ]; then
    rm -rf "$BUILD_TMP"
  fi
}

build_zip() {
  local out="$ROOT/dist/model-router.zip" tmp
  trap cleanup_build EXIT
  echo "== claude-app =="
  if [ ! -d "$SKILL_SRC" ]; then
    echo "error: missing $SKILL_SRC" >&2
    exit 1
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "would build $out"
  else
    mkdir -p "$ROOT/dist"
    tmp="$(mktemp -d)"
    BUILD_TMP="$tmp"
    mkdir "$tmp/model-router"
    cp -R "$SKILL_SRC/." "$tmp/model-router/"
    rm -f "$out"
    # Reproducible build: sorted entries, fixed timestamp and permissions, and
    # stored (uncompressed) entries so the bytes don't depend on the zlib version.
    python3 - "$tmp" "$out" <<'PY'
import os, sys, zipfile

src, out = sys.argv[1], sys.argv[2]
DATE = (1980, 1, 1, 0, 0, 0)
entries = []
for d, dirs, files in os.walk(src):
    for name in dirs:
        full = os.path.join(d, name)
        entries.append((os.path.relpath(full, src).replace(os.sep, "/") + "/", None))
    for name in files:
        full = os.path.join(d, name)
        entries.append((os.path.relpath(full, src).replace(os.sep, "/"), full))
entries.sort(key=lambda e: e[0])
with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
    for arc, full in entries:
        info = zipfile.ZipInfo(arc, DATE)
        info.create_system = 3
        info.compress_type = zipfile.ZIP_STORED
        if full is None:
            info.external_attr = (0o40755 << 16) | 0x10
            z.writestr(info, b"")
        else:
            info.external_attr = 0o100644 << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())
PY
    cleanup_build
    BUILD_TMP=""
    echo "built $out"
  fi
  echo
  if [ "$DRY" -eq 1 ]; then
    echo "Dry run: nothing was changed."
  fi
  echo "Upload dist/model-router.zip as a custom skill in Claude's skill settings."
  exit 0
}

if [ "$TARGET" = "claude-app" ]; then
  build_zip
fi

if [ "$TARGET" = "all" ]; then
  LIST="$PLATFORMS"
else
  case " $PLATFORMS " in
    *" $TARGET "*) LIST="$TARGET" ;;
    *) echo "error: unknown platform '$TARGET'" >&2; usage >&2; exit 2 ;;
  esac
fi

if [ -n "$PROJECT" ]; then
  if [ -d "$PROJECT" ]; then
    BASE="$(cd "$PROJECT" && pwd)"
  elif [ "$DRY" -eq 1 ]; then
    BASE="$PROJECT"
  else
    mkdir -p "$PROJECT"
    BASE="$(cd "$PROJECT" && pwd)"
  fi
  MODE="project"
else
  BASE="$HOME"
  MODE="user"
fi

# Sets SKILLS_DIR and AGENTS_DIR for a platform.
set_paths() {
  local p="$1"
  if [ "$MODE" = "user" ]; then
    case "$p" in
      claude-code) SKILLS_DIR="$BASE/.claude/skills";  AGENTS_DIR="$BASE/.claude/agents" ;;
      codex)       SKILLS_DIR="$BASE/.agents/skills";  AGENTS_DIR="$BASE/.codex/agents" ;;
      gemini-cli)  SKILLS_DIR="$BASE/.gemini/skills";  AGENTS_DIR="$BASE/.gemini/agents" ;;
      cursor)      SKILLS_DIR="$BASE/.cursor/skills";  AGENTS_DIR="$BASE/.cursor/agents" ;;
      copilot)     SKILLS_DIR="$BASE/.copilot/skills"; AGENTS_DIR="$BASE/.copilot/agents" ;;
    esac
  else
    case "$p" in
      claude-code) SKILLS_DIR="$BASE/.claude/skills";  AGENTS_DIR="$BASE/.claude/agents" ;;
      codex)       SKILLS_DIR="$BASE/.agents/skills";  AGENTS_DIR="$BASE/.codex/agents" ;;
      gemini-cli)  SKILLS_DIR="$BASE/.gemini/skills";  AGENTS_DIR="$BASE/.gemini/agents" ;;
      cursor)      SKILLS_DIR="$BASE/.cursor/skills";  AGENTS_DIR="$BASE/.cursor/agents" ;;
      copilot)     SKILLS_DIR="$BASE/.github/skills";  AGENTS_DIR="$BASE/.github/agents" ;;
    esac
  fi
}

INSTALLED=0
SKIPPED=0
UPTODATE=0
DIFFER=0
STAMP="$(date +%Y%m%d%H%M%S)"

# backup_path FILE: prints a backup name that does not exist yet.
backup_path() {
  local b="$1.bak.$STAMP" n=1
  while [ -e "$b" ]; do
    b="$1.bak.$STAMP.$n"
    n=$((n + 1))
  done
  echo "$b"
}

# install_file SRC DST
install_file() {
  local src="$1" dst="$2" bak
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      UPTODATE=$((UPTODATE + 1))
      return 0
    fi
    if [ "$FORCE" -eq 0 ]; then
      echo "skipped (differs, use --force): $dst"
      SKIPPED=$((SKIPPED + 1))
      DIFFER=$((DIFFER + 1))
      return 0
    fi
    bak="$(backup_path "$dst")"
    if [ "$DRY" -eq 1 ]; then
      echo "would back up $dst to $bak and overwrite"
    else
      cp -p "$dst" "$bak"
      cp "$src" "$dst"
      echo "overwrote $dst (backup: $bak)"
    fi
    INSTALLED=$((INSTALLED + 1))
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "would install $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "installed $dst"
  fi
  INSTALLED=$((INSTALLED + 1))
}

install_platform() {
  local p="$1" f rel
  local adapter="$ROOT/adapters/$p/agents"
  set_paths "$p"
  echo "== $p ($MODE) =="

  if [ ! -d "$SKILL_SRC" ]; then
    echo "error: missing $SKILL_SRC" >&2
    exit 1
  fi
  while IFS= read -r -d '' f; do
    rel="${f#"$SKILL_SRC"/}"
    install_file "$f" "$SKILLS_DIR/model-router/$rel"
  done < <(find "$SKILL_SRC" -type f -print0 | sort -z)

  if [ ! -d "$adapter" ]; then
    echo "error: missing $adapter" >&2
    exit 1
  fi
  for f in "$adapter"/*; do
    [ -f "$f" ] || continue
    install_file "$f" "$AGENTS_DIR/$(basename "$f")"
  done
}

next_steps() {
  case "$1" in
    claude-code) echo "claude-code: restart Claude Code, or start a new session, to load the skill and agents." ;;
    codex)       echo "codex: restart Codex so it picks up the skill and custom agents." ;;
    gemini-cli)  echo "gemini-cli: restart Gemini CLI; check that the router-* agents are listed." ;;
    cursor)      echo "cursor: restart Cursor or reload the window; check Settings for the skill and agents." ;;
    copilot)     echo "copilot: add the \`agent\` tool to your orchestrator agent so it can call the router-* agents." ;;
  esac
}

for p in $LIST; do
  install_platform "$p"
done

echo
if [ "$DRY" -eq 1 ]; then
  echo "Dry run: nothing was changed. $INSTALLED file(s) would be written, $SKIPPED skipped, $UPTODATE already up to date."
else
  echo "Done: $INSTALLED file(s) written, $SKIPPED skipped, $UPTODATE already up to date."
fi
if [ "$DIFFER" -gt 0 ]; then
  echo "$DIFFER files differ from this version and were kept; re-run with --force to update (backups are made)."
fi
echo "Next steps:"
for p in $LIST; do
  next_steps "$p"
done
