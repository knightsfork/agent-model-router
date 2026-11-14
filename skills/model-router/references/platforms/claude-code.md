# Platform reference: Claude Code (`claude-code`)

Read this once per session when you run in Claude Code.

## 1. How to spawn a subagent with a chosen model

Use the Agent tool. Set `model` and `effort` on every call, even when a preset agent already carries them:

- `model`: `haiku`, `sonnet`, `opus` or `fable`
- `effort`: `low`, `medium` or `high`
- `subagent_type`: a preset agent name (see section 3) or a general-purpose agent. **Never use `subagent_type: "fork"`.** Fork subagents inherit the parent's model and ignore `model`, so the routing silently does nothing.

Run independent parts in parallel by issuing the Agent calls in one message, up to `max_parallel_agents`.

## 2. Tier-to-model table

| Tier | `model` | `effort` |
|---|---|---|
| fast | `haiku` | low |
| standard | `sonnet` | medium |
| strong | `opus` | high |
| frontier | `fable` | high (only after user approval) |

These defaults come from the vendor's docs as of November 2026. Check the model list for your own plan.

## 3. Preset agents

The adapter ships `router-scout` (fast), `router-builder` (standard), `router-architect` (strong, writes), `router-reviewer` (strong, read-only review) and `router-deep-thinker` (frontier). Send strong-tier work to `router-architect` and strong-tier review to `router-reviewer`.

- Installed by `install.sh` into `~/.claude/agents/` (user) or `.claude/agents/` (project), or by the plugin.
- Call one by passing its name as `subagent_type`.
- When installed as a plugin, the name may carry a prefix, for example `model-router:router-scout`. Use the name exactly as the agent list shows it.
- Still set `model` and `effort` explicitly on every preset call. The frontmatter values are a fallback, not a substitute.
- The gate applies to presets too: do not call `router-deep-thinker` before the user approves the frontier tier for that part.

## 4. Caveats

- Fork subagents ignore `model`. Never route through them.
- The plugin cache is replaced when the plugin updates. Edit the files in the repo or in `~/.claude/agents/`, not in the cache, or your changes disappear on the next update.
- Ask for approval with the AskUserQuestion tool when it is available. Otherwise ask in plain chat and wait.
- Subagents return only a final message. Have them write large outputs to the files the brief names.

## 5. How to change the models

Edit the `model` and `effort` lines in the agent files (`~/.claude/agents/router-*.md` or `.claude/agents/router-*.md`). For a plugin install, copy the agents to one of those folders and edit the copies, or edit the repo and reinstall. Also change the `model` value you pass in Agent calls.

## 6. Sources

- https://code.claude.com/docs/en/sub-agents

## Verified

Tested with Claude Code's plugin validator.
