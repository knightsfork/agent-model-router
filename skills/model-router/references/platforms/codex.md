# Platform reference: OpenAI Codex (`codex`)

Read this once per session when you run in Codex.

## 1. How to spawn a subagent with a chosen model

Codex spawns subagents on request in natural language. Name the model and the effort in the request, for example: "Spawn a subagent on gpt-6-luna with low reasoning effort to extract the tables from these files." Also name the custom agent when you want a preset.

Model resolution order:

1. The model named when you spawn the subagent.
2. `[agents] default_subagent_model` in `config.toml`.
3. The parent's model.

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
- Each file sets `name`, `description`, `model`, `model_reasoning_effort` and `developer_instructions`. There is no tools field, so the instructions enforce the limits.
- Call one by name: "Use the router-builder agent to implement this spec."
- The gate applies to presets too: do not call `router-deep-thinker` before the user approves the frontier tier for that part.

## 4. Caveats

- Because of the resolution order, a model named at spawn time beats `default_subagent_model`, which beats the parent. Name the model on every spawn so the routing doesn't depend on config.
- Whether a custom agent's own `model` overrides a model named at spawn time is not confirmed. State both the agent and the model, and check which one ran.
- Ask for approval in plain chat unless Codex offers a structured question tool.

## 5. How to change the models

Edit `model` and `model_reasoning_effort` in `router-*.toml`. To change the fallback for subagents that name no model, set `default_subagent_model` under `[agents]` in `config.toml`.

## 6. Sources

- https://learn.chatgpt.com/docs/agent-configuration/subagents.md
- https://learn.chatgpt.com/docs/models.md

## Verified

Follows the vendor's documented format; not yet run end to end. Please report results.
