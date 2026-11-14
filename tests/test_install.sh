#!/usr/bin/env bash
# Installer tests. Run from anywhere: bash tests/test_install.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"
FAILS=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# mk prints a fresh directory under $WORK; it runs in a subshell, so cleanup
# relies on the single parent dir rather than on a list kept in a variable.
mk() { mktemp -d "$WORK/t.XXXXXX"; }
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILS=$((FAILS + 1)); }
check() { # check DESC CMD...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}

agent_files() { # platform -> file names
  local p="$1" ext names
  case "$p" in
    codex) ext=".toml" ;;
    copilot) ext=".agent.md" ;;
    *) ext=".md" ;;
  esac
  names="router-scout router-builder router-reviewer router-architect"
  [ "$p" = "copilot" ] || names="$names router-deep-thinker"
  for n in $names; do echo "$n$ext"; done
}

# dirs for a platform: sets SK and AG relative to a base, for mode user|project
dirs() {
  local p="$1" mode="$2"
  case "$p" in
    claude-code) SK=".claude/skills"; AG=".claude/agents" ;;
    codex) SK=".agents/skills"; AG=".codex/agents" ;;
    gemini-cli) SK=".gemini/skills"; AG=".gemini/agents" ;;
    cursor) SK=".cursor/skills"; AG=".cursor/agents" ;;
    copilot)
      if [ "$mode" = "user" ]; then SK=".copilot/skills"; AG=".copilot/agents"
      else SK=".github/skills"; AG=".github/agents"; fi ;;
  esac
}

run_install() { # base mode platform [extra args]
  local base="$1" mode="$2" p="$3"; shift 3
  if [ "$mode" = "user" ]; then
    HOME="$base" "$INSTALL" "$p" "$@"
  else
    HOME="$(mk)" "$INSTALL" "$p" --project "$base" "$@"
  fi
}

test_platform() {
  local p="$1" mode="$2" base out f
  echo "[$p / $mode]"
  base="$(mk)"
  dirs "$p" "$mode"

  run_install "$base" "$mode" "$p" >/dev/null 2>&1 || fail "install exits 0"
  check "SKILL.md installed" test -f "$base/$SK/model-router/SKILL.md"
  check "references installed" test -d "$base/$SK/model-router/references"
  for f in $(agent_files "$p"); do
    check "agent $f installed" test -f "$base/$AG/$f"
  done

  # Re-run without --force: nothing overwritten
  echo "LOCAL-EDIT" >> "$base/$SK/model-router/SKILL.md"
  first_agent="$(agent_files "$p" | head -1)"
  echo "LOCAL-EDIT" >> "$base/$AG/$first_agent"
  out="$(run_install "$base" "$mode" "$p" 2>&1)"
  check "rerun reports skipped" grep -qi "skipped" <<<"$out"
  check "SKILL.md not overwritten" grep -q "LOCAL-EDIT" "$base/$SK/model-router/SKILL.md"
  check "agent not overwritten" grep -q "LOCAL-EDIT" "$base/$AG/$first_agent"
  check "differ warning shown" grep -q "files differ from this version and were kept; re-run with --force to update (backups are made)." <<<"$out"
  check "no backup without --force" bash -c "! ls '$base/$SK/model-router/'SKILL.md.bak* >/dev/null 2>&1"

  # --force: backup created, file replaced
  run_install "$base" "$mode" "$p" --force >/dev/null 2>&1 || fail "force exits 0"
  bak1="$(find "$base/$SK/model-router" -name "SKILL.md.bak.*" | sort | head -1)"
  check "SKILL.md timestamped backup created" test -n "$bak1"
  check "backup name has timestamp" bash -c "[[ '$bak1' =~ \\.bak\\.[0-9]{14}\$ ]]"
  check "backup holds local edit" grep -q "LOCAL-EDIT" "$bak1"
  check "SKILL.md restored from repo" bash -c "! grep -q LOCAL-EDIT '$base/$SK/model-router/SKILL.md'"
  check "agent backup created" bash -c "ls '$base/$AG/'$first_agent.bak.* >/dev/null 2>&1"

  # --dry-run creates nothing
  base="$(mk)"
  out="$(run_install "$base" "$mode" "$p" --dry-run 2>&1)"
  check "dry-run prints actions" grep -qi "would" <<<"$out"
  check "dry-run creates nothing" bash -c "[ -z \"\$(find '$base' -mindepth 1 -print -quit)\" ]"
}

for p in claude-code codex gemini-cli cursor copilot; do
  test_platform "$p" user
  test_platform "$p" project
done

echo "[aliases and all]"
base="$(mk)"
HOME="$base" "$INSTALL" claude >/dev/null 2>&1
check "alias claude" test -f "$base/.claude/skills/model-router/SKILL.md"
HOME="$base" "$INSTALL" gemini >/dev/null 2>&1
check "alias gemini" test -f "$base/.gemini/skills/model-router/SKILL.md"
base="$(mk)"
HOME="$base" "$INSTALL" all >/dev/null 2>&1
for p in claude-code codex gemini-cli cursor copilot; do
  dirs "$p" user
  check "all installs $p" test -f "$base/$SK/model-router/SKILL.md"
done

echo "[claude-app zip]"
base="$(mk)"
rm -rf "$ROOT/dist"
out="$(HOME="$base" "$INSTALL" claude-app 2>&1)"
check "claude-app builds zip" test -f "$ROOT/dist/model-router.zip"
check "claude-app prints upload hint" grep -q "Upload dist/model-router.zip as a custom skill in Claude's skill settings." <<<"$out"
check "zip has model-router/SKILL.md" python3 -c "
import sys, zipfile
n = zipfile.ZipFile(sys.argv[1]).namelist()
assert 'model-router/SKILL.md' in n
assert any(x.startswith('model-router/references/platforms/claude-app.md') for x in n)
assert all(x.startswith('model-router/') for x in n)" "$ROOT/dist/model-router.zip"
check "claude-app writes nothing to HOME" bash -c "[ -z \"\$(find '$base' -mindepth 1 -print -quit)\" ]"
rm -rf "$ROOT/dist"
HOME="$base" "$INSTALL" claude-app >/dev/null 2>&1
sum1="$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$ROOT/dist/model-router.zip")"
rm -rf "$ROOT/dist"
sleep 1
HOME="$base" "$INSTALL" claude-app >/dev/null 2>&1
sum2="$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$ROOT/dist/model-router.zip")"
check "claude-app zip is byte-identical across two builds" test -n "$sum1" -a "$sum1" = "$sum2"
check "zip entries sorted, fixed timestamp and permissions" python3 -c "
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = [i.filename for i in z.infolist()]
assert names == sorted(names), 'not sorted'
assert 'model-router/' in names and 'model-router/references/platforms/' in names
for i in z.infolist():
    assert i.date_time == (1980, 1, 1, 0, 0, 0), i.filename
    mode = i.external_attr >> 16
    assert mode == (0o40755 if i.filename.endswith('/') else 0o100644), (i.filename, oct(mode))" "$ROOT/dist/model-router.zip"
rm -rf "$ROOT/dist"
HOME="$base" "$INSTALL" claude-desktop >/dev/null 2>&1
check "alias claude-desktop builds zip" test -f "$ROOT/dist/model-router.zip"
rm -rf "$ROOT/dist"
out="$(HOME="$base" "$INSTALL" claude-app --dry-run 2>&1)"
check "claude-app dry-run prints would" grep -qi "would" <<<"$out"
check "claude-app dry-run creates no zip" bash -c "! test -e '$ROOT/dist'"
check "claude-app dry-run writes nothing to HOME" bash -c "[ -z \"\$(find '$base' -mindepth 1 -print -quit)\" ]"
base="$(mk)"
HOME="$base" "$INSTALL" all >/dev/null 2>&1
check "all does not build the zip" bash -c "! test -e '$ROOT/dist'"

echo "[idempotence and backups]"
base="$(mk)"
HOME="$base" "$INSTALL" claude-code >/dev/null 2>&1
out="$(HOME="$base" "$INSTALL" claude-code 2>&1)"
check "identical files skipped silently" bash -c "! grep -qi 'skipped (' <<<'$out'"
check "identical rerun reports up to date" grep -q "already up to date" <<<"$out"
check "identical rerun no differ warning" bash -c "! grep -q 'files differ' <<<'$out'"
HOME="$base" "$INSTALL" claude-code --force >/dev/null 2>&1
check "force on identical files makes no backup" bash -c "! find '$base' -name '*.bak*' | grep -q ."
f="$base/.claude/agents/router-scout.md"
echo "ORIGINAL-USER-CONTENT" > "$f"
HOME="$base" "$INSTALL" claude-code --force >/dev/null 2>&1
echo "SECOND-USER-CONTENT" > "$f"
HOME="$base" "$INSTALL" claude-code --force >/dev/null 2>&1
baks="$(find "$base/.claude/agents" -name "router-scout.md.bak.*" | sort)"
check "two forced runs keep two backups" bash -c "[ \"\$(wc -l <<<'$baks')\" -eq 2 ]"
check "first backup keeps original content" grep -q "ORIGINAL-USER-CONTENT" "$(head -1 <<<"$baks")"
check "second backup holds second content" grep -q "SECOND-USER-CONTENT" "$(tail -1 <<<"$baks")"
# Same-second collision: pre-existing backup must never be overwritten
echo "KEEP-ME" > "$f"
HOME="$base" "$INSTALL" claude-code --force >/dev/null 2>&1
check "existing backups never overwritten" bash -c "grep -q ORIGINAL-USER-CONTENT '$(head -1 <<<"$baks")'"
check "new content also backed up" bash -c "grep -l KEEP-ME '$f'.bak.* >/dev/null"

echo "[bad input]"
check "unknown platform fails" bash -c "! '$INSTALL' nope >/dev/null 2>&1"
check "empty --project fails" bash -c "! '$INSTALL' codex --project '' >/dev/null 2>&1"
check "empty --project error message" bash -c "'$INSTALL' codex --project '' 2>&1 | grep -qi error"
check "missing --project argument fails" bash -c "! '$INSTALL' codex --project >/dev/null 2>&1"

echo
if [ "$FAILS" -eq 0 ]; then echo "All tests passed."; else echo "$FAILS test(s) failed."; exit 1; fi
