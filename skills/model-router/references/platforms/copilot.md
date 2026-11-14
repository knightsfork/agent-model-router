# Platform reference: GitHub Copilot (`copilot`)

Read this once per session when the harness is GitHub Copilot (VS Code agent mode or another Copilot surface). Model defaults come from GitHub's and VS Code's docs as of November 2026. Check the model list for your own plan, because availability and names vary by plan and surface.

## 1. How to spawn a subagent with a chosen model

Subagents are called through the `agent` tool. The orchestrator must have `agent` in its tools.

- With the default agent, call a subagent by name (for example `router-builder`).
- With your own custom agent as orchestrator, add `agent` to its `tools` and list the presets it may call:
  `agents: ['router-scout','router-builder','router-architect','router-reviewer']`
- The model is set in each preset's frontmatter. The caller may request a model, but a subagent can't use a model that costs more than the parent's.

Names are case-sensitive. Use `router-scout`, not `Router-Scout`.

## 2. Tier-to-model table

| Tier | Preset agent | Model (VS Code strings) | Effort |
|---|---|---|---|
| `fast` | `router-scout` | `Claude Haiku 4.5 (copilot)`, then `GPT-5.4 mini (copilot)` | low |
| `standard` | `router-builder` | `Claude Sonnet 5.5 (copilot)` | medium |
| `strong` | `router-architect` (work), `router-reviewer` (review) | `Claude Opus 5.5 (copilot)` | high |
| `frontier` | none shipped | the top model you choose in the main chat | high |

The `model` field is a prioritized list. Copilot uses the first model available to you. There is no effort field, so effort is guidance for the brief.

## 3. Preset agents

Files: `router-{scout,builder,architect,reviewer}.agent.md`, in the adapter folder at https://github.com/knightsfork/agent-model-router/tree/main/adapters/copilot/agents (the `adapters/` folder isn't installed with the skill).

- User install: `~/.copilot/agents/`
- Project install: `.github/agents/`

Frontmatter fields: `name`, `description`, `model` (list), `tools` (list).

- Scout tools: `read`, `search`, `web`, `edit`
- Builder tools: `read`, `search`, `edit`, `execute`
- Architect tools: `read`, `search`, `edit`, `execute`, `web`
- Reviewer tools: `read`, `search`, `execute` (no edit)

The presets do not set `user-invocable: false`, because it is unverified across surfaces. Add it yourself if your surface supports it and you want the presets out of the agent picker.

## 4. Platform caveats

- **Cost ceiling.** A subagent can't use a model that costs more than the parent. If the main chat runs a cheap model, a `strong` preset may be refused or downgraded. Run the main chat on a model at least as strong as the highest tier you plan to delegate. If a requested `strong` preset is refused because it costs more than the parent, either run that part in the main chat when the main model is strong enough, or ask the user to switch the main chat to a stronger model and then retry.
- **No frontier preset.** Because of the ceiling, the frontier tier can't be a subagent. Ask the user for approval as usual. After approval, run that part in the main chat if the main model is top-tier, or tell the user to switch the main chat to a top model first. This is the exception to the rule that the main thread doesn't do the work.
- **Model strings differ by surface.** VS Code uses the `(copilot)` suffix. Other surfaces (GitHub.com, CLI, JetBrains) may use different strings. Check the picker on your surface.
- **Names are case-sensitive**, both for agents and for entries in an `agents:` list.
- The `agent` tool must be enabled for the orchestrator, or no subagent call is possible.
- Read-only: the reviewer has `edit` removed but keeps `execute` so it can run checks, so it is not a hard read-only boundary; the shell can still change files. For sensitive reviews, run the session itself in a read-only mode.

## 5. How to change the models

1. Open the preset's `.agent.md` file.
2. Edit the `model` list. Put the preferred model first.
3. Use the exact string your surface shows in its model picker.
4. Reload the window or start a new chat.

## 6. Sources

- https://code.visualstudio.com/docs/copilot/agents/subagents
- https://docs.github.com/en/copilot/reference/ai-models/supported-models

## 7. Verified

Follows the vendor's documented format; not yet run end to end. Please report results.
