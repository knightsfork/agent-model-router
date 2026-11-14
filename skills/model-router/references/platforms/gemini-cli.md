# Platform reference: Gemini CLI (`gemini-cli`)

Read this once per session when you run in Gemini CLI.

## 1. How to spawn a subagent with a chosen model

You can't pass a model per call. Each subagent's model is set in its own definition file. To route a part to a tier, call the preset agent for that tier (section 3). `model` defaults to `inherit`, which means the parent's model, so a custom agent with no `model` line is not routed.

## 2. Tier-to-model table

| Tier | Model | Preset agent |
|---|---|---|
| fast | `gemini-2.5-flash` | `router-scout` |
| standard | `gemini-3-flash-preview` | `router-builder` |
| strong | `gemini-3-pro-preview` | `router-architect` (work), `router-reviewer` (review) |
| frontier | `gemini-3-pro-preview` | `router-deep-thinker` (only after user approval) |

These defaults come from the vendor's docs as of November 2026. Check the model list for your own plan. The fast and frontier IDs are best-effort: Gemini CLI has no separate top model, and Flash-Lite IDs aren't confirmed. Frontier uses the same model as strong here, because Gemini CLI has no separate top model. It differs only by its role and its approval gate.

## 3. Preset agents

- Presets: `router-scout`, `router-builder`, `router-architect`, `router-reviewer`, `router-deep-thinker`. Strong-tier work goes to `router-architect`, strong-tier review to `router-reviewer`.
- Install into `~/.gemini/agents/` (user) or `.gemini/agents/` (project). Skills go in `~/.gemini/skills/` or `.gemini/skills/`.
- Frontmatter: `name`, `description`, `kind: local`, `model`, `temperature: 0.2`, `max_turns`. There is no `tools` field, because tool names are unverified; the body text enforces the limits.
- Call one by name, for example: "Use the router-scout agent to list every file that mentions X."
- The gate applies to presets too: do not call `router-deep-thinker` before the user approves the frontier tier for that part.

## 4. Caveats

- The model is fixed per definition. To run the same role on a different model, you need a second agent file.
- `max_turns` caps each agent (scout 15, builder 30, architect 30, reviewer 20, deep-thinker 20). Raise it if long jobs stop early.
- Ask for approval in plain chat and wait for the answer.
- Read-only: instruction only; no tools list is set.

## 5. How to change the models

Edit the `model` line in `~/.gemini/agents/router-*.md` or `.gemini/agents/router-*.md`. Use `/model` or the model docs to see which IDs your plan offers.

## 6. Sources

- https://geminicli.com/docs/core/subagents.md
- https://geminicli.com/docs/cli/model/

## Verified

Follows the vendor's documented format; not yet run end to end. Please report results.
