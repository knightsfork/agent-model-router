# Platform reference: OpenAI Codex (`codex`)

Read this once per session when you run in Codex.

## 1. How to spawn a subagent with a chosen model

Codex spawns subagents on request in natural language. With the presets installed, route by calling the preset for the tier by name, for example: "Use the router-scout agent to extract the tables from these files." The preset's own `model` and `model_reasoning_effort` win over anything named at spawn time, so the preset is what picks the model.

To use a model that has no preset, spawn a plain (non-preset) subagent and name the model and the effort in the request, for example: "Spawn a subagent on gpt-6-luna with low reasoning effort to extract the tables from these files."

Model precedence:

1. If a custom agent file sets `model` or `model_reasoning_effort`, the file wins over a model requested at spawn time.
2. Spawn-time values only override `[agents] default_subagent_model` / `default_subagent_reasoning_effort` and the parent's model, and only for agents without those keys.

So with presets installed, route by calling the preset for the tier. A gated tier can't be avoided by naming a lower model on a preset call: if `strong` is gated, ask the user first before calling `router-architect` or `router-reviewer`.

## 2. Tier-to-model table

| Tier | Model | `model_reasoning_effort` |
|---|---|---|
| fast | `gpt-6-luna` | low |
| standard | `gpt-6.1-terra` | medium |
| strong | `gpt-6.1-sol` | high (`router-architect` for work, `router-reviewer` for review) |
| frontier | `gpt-6-astra` | high (only after user approval) |

These defaults come from the vendor's docs as of November 2026. Check the model list for your own plan.

## 3. Preset agents

The adapter ships `router-scout`, `router-builder`, `router-architect`, `router-reviewer` and `router-deep-thinker` as TOML files. Strong-tier work goes to `router-architect` and strong-tier review to `router-reviewer`.

- Install into `~/.codex/agents/` (user) or `.codex/agents/` (project). Skills go in `~/.agents/skills/` or `.agents/skills/`.
- Each file sets `name`, `description`, `model`, `model_reasoning_effort` and `developer_instructions`. There is no tools field, so the instructions set the limits. The file can also set `features.*` keys; the read-only presets switch off `features.apps`, `features.plugins` and `features.request_permissions_tool`.
- Call one by name: "Use the router-builder agent to implement this spec."
- The gate applies to presets too: do not call `router-deep-thinker` before the user approves the frontier tier for that part.

## 4. Caveats

- A model named at spawn time does not override a preset's own `model`. Route by calling the preset for the tier. For a plain subagent, name the model on every spawn so the routing doesn't depend on config.
- Read-only: instruction only. Subagents inherit the parent's sandbox and approvals, and a custom agent file can't override `sandbox_mode` or `approval_policy`. The read-only presets switch off `features.apps`, `features.plugins` and `features.request_permissions_tool`. Use a read-only Codex session for sensitive reviews.
- Ask for approval in plain chat unless Codex offers a structured question tool.

## 5. How to change the models

Edit `model` and `model_reasoning_effort` in `router-*.toml`. To change the fallback for subagents that name no model, set `default_subagent_model` under `[agents]` in `config.toml`.

## 6. Sources

- https://learn.chatgpt.com/docs/agent-configuration/subagents.md (model precedence for custom agents and spawn-time values)
- https://learn.chatgpt.com/docs/models.md

## Verified

Ran in a live session. The author ran the plugin in Codex, which spawned a fast-tier subagent. Not yet fully tested end to end. Please report results.
