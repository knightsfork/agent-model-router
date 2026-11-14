# Changelog

## 1.0.3 - 2026-11-14

Fixes from a second external review.

- Checkpoint IDs can no longer collide. `<project-id>` is now the percent-encoded absolute working-folder path (every byte except ASCII letters, digits, `.`, `_` and `-` becomes `%XX`, so `/work/team-a/app` is `%2Fwork%2Fteam-a%2Fapp` and `/work/team/a-app` is `%2Fwork%2Fteam%2Fa-app`). Session files are `_state-<YYYYmmdd-HHMMSS>-<6 random hex chars>-<slug>.md`, and the skill checks the name is unused before creating the file. It states the checkpoint path once in the chat, resumes from that exact path after compaction, and in a new chat lists the project's checkpoints and asks which to resume if more than one could be the same task. SKILL.md and the README use the same paths.
- Release zips are reproducible. `install.sh claude-app` builds `dist/model-router.zip` with python3 `zipfile` only: entries stored uncompressed (`ZIP_STORED`, so the bytes don't depend on the zlib version), sorted by path (directories included), timestamp `1980-01-01 00:00:00`, permissions 0644 for files and 0755 for directories. Two builds from the same tree are byte-identical, and `tests/test_install.sh` checks it.
- Releases recover from partial uploads. The new `scripts/publish-release.sh TAG [--replace] [--dry-run]` creates the release if needed (with `--verify-tag`), uploads missing assets, skips assets whose sha256 already matches, fails (without changing anything) on an asset that differs unless `--replace` is given, and replaces safely: upload `<name>.new`, verify it by downloading, delete the old asset, then rename and verify the result. A failure at any step leaves the old or the new asset on the release, never neither, and the message says what state the release is in. Re-running is always safe. The release workflow calls it, and `tests/test_publish.sh` covers it with a fake `gh` that applies the script's `--jq` expressions with real `jq`, models git tags (so a release can't be created for a missing tag) and models asset states.
- A broken asset no longer blocks re-runs. The asset listing now includes each asset's `state`. An asset whose state is not `uploaded` (for example `starter`, left by a failed upload) was never a valid published file, so the script deletes it and uploads it fresh, with or without `--replace`, and logs what it did. With `--replace`, an existing asset that can't be downloaded for the comparison counts as different and is replaced safely; without `--replace` the run fails with a clear message.
- Finishing an interrupted rename (a `.new` left by an earlier run) now downloads and verifies the renamed asset, like the main replace path. If the zip was replaced but the checksum replace then fails, the error says the release now has the new zip with the old checksum and to re-run with `--replace`.
- The script validates its input before any `gh` call: `TAG` must match `^v[0-9]+\.[0-9]+\.[0-9]+$` and `GITHUB_REPOSITORY` must be `owner/repo` with only letters, digits, `.`, `_` and `-`. Both checks are Bash 3.2 safe.
- Release workflow: a first step rejects tags older than v1.0.3 (compared numerically) with "Releases before v1.0.3 were published by an earlier workflow; this workflow supports v1.0.3 and later.", because older tags don't contain `tests/test_publish.sh` and `scripts/publish-release.sh`. The checkout uses `persist-credentials: false`, `pyyaml` is pinned to `6.0.2`, and the manual-run example tag is v1.0.3. `tests/test_publish.sh` runs the real old-tag step from the workflow file.

## 1.0.2 - 2026-11-14

- Release workflow: the zip is now built from the exact tag being released. The workflow checks out that tag, fails if `HEAD` isn't the tag's commit, and never overwrites an existing `model-router.zip` or `model-router.zip.sha256`. A manual run can replace them only with the new `replace_asset` input set to `true`, and the replacement is still built from the tag. `actions/checkout` is pinned to a full commit SHA.
- New `model-router.zip.sha256` file is attached to each release so the download can be verified (`shasum -a 256 -c` on macOS, `sha256sum -c` on Linux).
- Checkpoint paths no longer collide: `<project-id>` is the absolute working-folder path with the leading `/` removed and `/`, `\` and `:` replaced by `-`, and each session writes its own `_state-<YYYYmmdd-HHMM>-<short-task-slug>.md`. After compaction or in a new chat the skill reads the most recent file and starts a new one for new work. The routing log is at `~/.model-router/logs/<project-id>/routing-log.md`.

## 1.0.1 - 2026-11-14

Fixes from an external security and efficiency review.

- `tests/test_install.sh` no longer leaks temporary folders: one work dir with an `EXIT` trap replaces the `TMPS` array, and the script is Bash 3.2 compatible.
- `scripts/validate.py` no longer requires PyYAML. A built-in fallback parser is used when it is missing, and `MR_NO_YAML=1` forces it.
- Codex presets `router-scout`, `router-reviewer` and `router-deep-thinker` switch off `features.apps`, `features.plugins` and `features.request_permissions_tool`.
- README: Codex status is now "Ran in a live session", plus a Security section, the new settings, the delegation-overhead limitation and the Codex preset note.
- Codex gate fix: on Codex, if `strong` is gated, the orchestrator asks the user before calling `router-architect` or `router-reviewer`, because an installed preset's `model` wins over a model named at spawn time. `codex.md` now leads with preset-based routing and lists the `features.*` keys.
- Honest read-only wording: the Claude Code and Copilot reviewers keep shell access (`Bash`, `execute`), so they are not a hard read-only boundary. The Claude Code deep-thinker can't write, and Cursor's `readonly: true` blocks edits and state-changing shell commands. Advice kept: run the session in the platform's read-only mode for sensitive reviews.
- Collision-safe paths: checkpoints and routing logs use `<parent-folder>-<project-folder>`, and the README paths and `delegation` wording now match SKILL.md. Codex status is the same in every file.
- `scripts/validate.py` fallback parser returns ints and floats as numbers and `true`/`false` as booleans, matching PyYAML.
- `install.sh` removes its temporary build folder on every exit path, and `.gitignore` covers `__pycache__/`.
- Skill text: checkpoints are written outside the repo by default, a `delegation` setting (`auto | on_request`) with tighter delegation rules, the Codex precedence fix (the preset's model wins over a model named at spawn), read-only enforcement notes per platform, backstop wording for the frontier gate, and no secrets in briefs.

## 1.0.0 - 2026-11-14

First public release.

- `model-router.zip` is attached to the GitHub release, so the Claude desktop app can be set up with no terminal: download, then upload it as a custom skill.
- The README has a tier-to-model map across every platform.

- One vendor-neutral `model-router` skill in the Agent Skills format. The main chat model orchestrates and sends each part of a task to the cheapest tier that will do it well.
- Four neutral tiers: `fast`, `standard`, `strong` and `frontier`, each with a default effort level. A new Step 0 has the skill identify its harness and read the matching platform reference once per session.
- Six platforms: Claude Code, Claude apps (desktop, web and mobile), OpenAI Codex, Gemini CLI, Cursor and GitHub Copilot. The Claude apps use general-purpose agents with `model` and `effort` on every call, and have no preset agents. Each has a platform reference file and a generic fallback, with model defaults taken from vendor docs as of November 2026.
- Preset agents on every platform: `router-scout` (fast), `router-builder` (standard), `router-architect` (strong, writable, for judgment-heavy work) and `router-reviewer` (strong, read-only). `router-deep-thinker` (frontier, gated) ships on every platform except Copilot, where a subagent can't cost more than its parent.
- Frontier tier is gated: it runs only after the user approves it (`approval_required_tiers: [frontier]`). Untried parts drop to the tier below if approval is declined, and the gate also applies to preset agents.
- `install.sh` installs the skill and agents for one platform or all of them, at user level or into a project with `--project`. It skips files that are identical to this version, never overwrites a differing file without `--force`, warns how many differing files were kept, backs up to a timestamped `<file>.bak.<YYYYmmddHHMMSS>` when forced (never overwriting an existing backup), rejects an empty `--project`, and supports `--dry-run`.
- `install.sh claude-app` (alias `claude-desktop`) builds `dist/model-router.zip` to upload as a custom skill in Claude's skill settings. It writes nothing under `$HOME` and isn't part of `all`.
- `scripts/validate.py` checks the skill frontmatter against the Agent Skills spec and every adapter agent file (YAML and TOML), and `tests/test_install.sh` tests the installer in temporary directories.
- Claude Code plugin packaging: `plugin.json`, a self-hosted `marketplace.json` and an icon.
- Carried over from the earlier Claude-only draft:
  - Settings block: `approval_required_tiers`, `max_parallel_agents` and `routing_log`, plus the fallback rule for model values that are rejected or unavailable.
  - Orchestrator rules: quick steps stay inline, parallel patterns, escalation including blocked parts, and `_state.md` checkpoints for compaction.
  - The routing line, and the optional routing log in `_routing-log.md` for tuning the tier table.
  - Brief templates per tier and worked decomposition examples.
