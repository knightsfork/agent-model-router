# Changelog

## 1.0.0 - 2026-11-14

First public release.

- One vendor-neutral `model-router` skill in the Agent Skills format. The main chat model orchestrates and sends each part of a task to the cheapest tier that will do it well.
- Four neutral tiers: `fast`, `standard`, `strong` and `frontier`, each with a default effort level. A new Step 0 has the skill identify its harness and read the matching platform reference once per session.
- Five platforms: Claude Code, OpenAI Codex, Gemini CLI, Cursor and GitHub Copilot. Each has a platform reference file and a generic fallback, with model defaults taken from vendor docs as of November 2026.
- Preset agents on every platform: `router-scout` (fast), `router-builder` (standard), `router-architect` (strong, writable, for judgment-heavy work) and `router-reviewer` (strong, read-only). `router-deep-thinker` (frontier, gated) ships on every platform except Copilot, where a subagent can't cost more than its parent.
- Frontier tier is gated: it runs only after the user approves it (`approval_required_tiers: [frontier]`). Untried parts drop to the tier below if approval is declined, and the gate also applies to preset agents.
- `install.sh` installs the skill and agents for one platform or all of them, at user level or into a project with `--project`. It skips files that are identical to this version, never overwrites a differing file without `--force`, warns how many differing files were kept, backs up to a timestamped `<file>.bak.<YYYYmmddHHMMSS>` when forced (never overwriting an existing backup), rejects an empty `--project`, and supports `--dry-run`.
- `scripts/validate.py` checks the skill frontmatter against the Agent Skills spec and every adapter agent file (YAML and TOML), and `tests/test_install.sh` tests the installer in temporary directories.
- Claude Code plugin packaging: `plugin.json`, a self-hosted `marketplace.json` and an icon.
- Carried over from the earlier Claude-only draft:
  - Settings block: `approval_required_tiers`, `max_parallel_agents` and `routing_log`, plus the fallback rule for model values that are rejected or unavailable.
  - Orchestrator rules: quick steps stay inline, parallel patterns, escalation including blocked parts, and `_state.md` checkpoints for compaction.
  - The routing line, and the optional routing log in `_routing-log.md` for tuning the tier table.
  - Brief templates per tier and worked decomposition examples.
