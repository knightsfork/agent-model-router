# agent-model-router

A skill that makes your coding agent route work to the right model. The main chat model acts as the orchestrator. It splits a task into parts and sends each part to the cheapest model tier that can do it well: simple extraction and searches go to a small model, routine builds to a mid-tier model, and judgment calls to a strong one. A fresh agent reviews the results before they reach you. The goal is lower cost and better focus on long tasks, without giving up quality where it matters.

The skill follows the Agent Skills format. It works in coding agents that can spawn subagents with their own model: Claude Code, OpenAI Codex, Gemini CLI, Cursor and GitHub Copilot.

## How it works

The orchestrator keeps small steps for itself and delegates the rest. It writes a short brief for each delegated part, runs independent parts in parallel, and checks the results. Tiers are neutral names; each platform maps them to its own models.

| Tier | Use for | Default effort |
|---|---|---|
| `fast` | Mechanical, rule-bound work you can check at a glance: extraction, conversion, searches, single-document summaries, grep | low |
| `standard` | Production work with a clear spec: features from a spec, documents from an outline, research synthesis, routine debugging, routine reviews | medium |
| `strong` | Judgment, ambiguity, high stakes: architecture, compliance gap judgments, security reviews, executive narratives, multi-file refactors, high-stakes review | high |
| `frontier` | The hardest few percent of problems. Runs only after you approve it | high |

At the end of a task that used delegation, the skill prints a line such as `Routing: 4× fast (extraction), 2× standard (build), 1× strong (review).`

## Supported platforms

| Platform | Skill | Preset agents | How the model is chosen | Status |
|---|---|---|---|---|
| Claude Code | Yes | Yes | `model` and `effort` on every Agent tool call, and in the preset agents' frontmatter | Tested (plugin validator) |
| OpenAI Codex | Yes | Yes | Name the model when spawning; custom agents set `model` and `model_reasoning_effort` | Documented format, not yet tested end to end |
| Gemini CLI | Yes | Yes | Set in each agent's frontmatter; call the preset for the tier | Documented format, not yet tested end to end |
| Cursor | Yes | Yes | Set in each agent's frontmatter; call the preset for the tier | Documented format, not yet tested end to end |
| GitHub Copilot | Yes | Yes (no frontier preset) | Set in each agent's frontmatter; a subagent can't cost more than the parent | Documented format, not yet tested end to end |

## Quick install

### Claude Code plugin

Requires Claude Code 2.1.275 or later (per Claude Code's plugin validator).

```
/plugin install model-router --marketplace knightsfork/agent-model-router
```

From a shell:

```
claude plugin install model-router --marketplace knightsfork/agent-model-router
```

If that form isn't available in your version, use two steps:

```
/plugin marketplace add knightsfork/agent-model-router
/plugin install model-router@model-router
```

### Any tool

```
git clone https://github.com/knightsfork/agent-model-router.git
cd agent-model-router
./install.sh <platform>
```

`<platform>` is `claude-code`, `codex`, `gemini-cli`, `cursor`, `copilot` or `all`. The aliases `claude` and `gemini` also work. By default the installer writes to your user-level folders under `$HOME`. To install into one project, add `--project DIR`:

```
./install.sh codex --project ~/work/my-repo
```

The installer never overwrites an existing file that differs from this version. It skips identical files silently and keeps the others, then tells you how many differ. Add `--force` to overwrite; each replaced file is first saved as `<file>.bak.<YYYYmmddHHMMSS>`, and an existing backup is never overwritten. Add `--dry-run` to see what would happen without changing anything. It works from any directory.

### Manual install

Copy `skills/model-router` into the skill folder and the files from `adapters/<platform>/agents/` into the agents folder.

| Platform | Skill folder (user) | Skill folder (project) | Agents folder (user) | Agents folder (project) |
|---|---|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` | `~/.claude/agents/` | `.claude/agents/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` | `~/.codex/agents/` | `.codex/agents/` |
| Gemini CLI | `~/.gemini/skills/` | `.gemini/skills/` | `~/.gemini/agents/` | `.gemini/agents/` |
| Cursor | `~/.cursor/skills/` | `.cursor/skills/` | `~/.cursor/agents/` | `.cursor/agents/` |
| Copilot | `~/.copilot/skills/` | `.github/skills/` | `~/.copilot/agents/` | `.github/agents/` |

Cursor also reads `.claude/` and `.codex/` agent folders, and its own `.cursor/` versions take precedence. If you use several tools, install each tool's adapter.

## Platform notes

**Claude Code.** The orchestrator passes `model` and `effort` on each Agent tool call. Fork subagents ignore `model`, so the skill never routes through them. The preset agents also set model and effort in their frontmatter. The plugin registers the agents from `adapters/claude-code/agents/`.

**OpenAI Codex.** Ask for the model in plain language when spawning. The model is resolved in this order: the value in the spawn request, then `[agents] default_subagent_model` in `config.toml`, then the parent's model. Custom agents are TOML files with `model` and `model_reasoning_effort`.

**Gemini CLI.** The model belongs to the agent definition and can't be passed per call, so the skill routes by calling the preset agent for the tier. The `fast` and `frontier` model IDs are best effort: Gemini CLI has no separate top model, and Flash-Lite IDs aren't confirmed.

**Cursor.** The model is set in agent frontmatter, and `inherit` is the default. The parent can name a model when it launches an agent, but whether that overrides the frontmatter is unconfirmed, so the skill routes through the presets.

**GitHub Copilot.** The model is set in agent frontmatter as a string or a prioritized list. Subagents run through the `agent` tool, so add `agent` to your orchestrator agent's tools. Model names vary by surface; VS Code uses the `(copilot)` suffix.

## Preset agents

| Agent | Tier | Can write? | Purpose |
|---|---|---|---|
| `router-scout` | fast | Only the one output file named in the brief | Extraction, searching, file inventories, summaries of bulk material. Returns evidence with sources, never conclusions |
| `router-builder` | standard | Yes | Builds code, documents, sheets or decks from a written spec with acceptance criteria |
| `router-architect` | strong | Yes | Judgment-heavy work: architecture and design decisions, ambiguous requirements, root-cause analysis, multi-file refactors, high-stakes writing |
| `router-reviewer` | strong | No (read-only, runs checks) | Fresh, independent review of work against its goal and acceptance criteria |
| `router-deep-thinker` | frontier (gated) | No | Hard problems, only after you approve the frontier tier for that part. Not shipped for Copilot |

## Configuration

The Settings block in `skills/model-router/SKILL.md` controls the orchestrator:

```
approval_required_tiers: [frontier]
max_parallel_agents: 5
routing_log: false
recommended_main_tier: strong
```

- `approval_required_tiers`: tiers that need your approval before they run.
- `max_parallel_agents`: how many delegated agents run at once.
- `recommended_main_tier`: the tier you should run the main chat model on, since the orchestrator's own judgment sets the quality of every delegation.
- `routing_log`: when `true`, each routing decision is recorded in `_routing-log.md` so you can tune the tier table.

To change which model a tier uses, edit the `model` (and effort) values in the adapter files you installed, or the tier table in `skills/model-router/references/platforms/<platform>.md`. Then reinstall with `--force`, or edit the installed copies directly.

Plugin installs on Claude Code are replaced when the plugin updates, so edits to plugin files are lost. To keep custom models, copy the agents into `~/.claude/agents/` or `.claude/agents/` and edit them there.

## Limitations

- Model defaults come from each vendor's docs as of November 2026. Check the model list for your own plan and edit the defaults if they differ.
- The frontier tier is gated. It never runs without your approval, and untried parts drop to the tier below; parts that already failed are reported as blocked.
- Copilot: a subagent can't use a model that costs more than its parent. No frontier preset is shipped; the frontier tier there means running the part in the main chat on a top model, after approval.
- Gemini CLI, Cursor and Copilot set the model per agent definition, so routing means calling the right preset.
- The orchestrator can't run `/compact` itself. On long jobs it writes progress to `_state.md` so work survives compaction.
- Savings aren't guaranteed. Delegation adds overhead, and short tasks may cost more than doing them inline.
- Consumer chat apps without subagents can't use it. There the skill does the work directly and skips the routing line.
- Only Claude Code is tested, with the plugin validator. The other platforms follow the vendors' documented formats but haven't been run end to end. Please report results.

## Repository layout

```
.claude-plugin/        plugin.json, marketplace.json, icon.png
skills/model-router/
  SKILL.md             vendor-neutral core
  references/
    brief-templates.md
    decomposition-examples.md
    platforms/         claude-code, codex, gemini-cli, cursor, copilot, generic
adapters/
  claude-code/agents/  router-*.md
  codex/agents/        router-*.toml
  gemini-cli/agents/   router-*.md
  cursor/agents/       router-*.md
  copilot/agents/      router-*.agent.md
install.sh             installer
tests/test_install.sh  installer tests
scripts/validate.py    skill and agent file validator
```

## Contributing

Before opening a pull request, run both checks:

```
python3 scripts/validate.py
bash tests/test_install.sh
```

`validate.py` needs Python 3.11 or later and `pyyaml`. If you test a platform end to end, please open an issue with the result.

## License

MIT. Copyright (c) 2026 Hatem Mohamed.
