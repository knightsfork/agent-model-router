# Platform reference: Cursor (`cursor`)

Read this once per session when the harness is Cursor. Model defaults come from Cursor's docs as of November 2026. Check the model list for your own plan, because availability and names vary by plan.

## 1. How to spawn a subagent with a chosen model

In Cursor the model is set per agent definition (the `model` field in frontmatter, default `inherit`). Route by calling the preset agent for the tier, not by passing a model in the call. The parent may name a model when it launches a subagent, but whether that overrides the frontmatter is unconfirmed, so don't rely on it.

To run a part on a tier, call the preset by name (for example `router-builder`) and put the full brief in the call.

## 2. Tier-to-model table

| Tier | Preset agent | Model slug | Effort |
|---|---|---|---|
| `fast` | `router-scout` | `claude-haiku-5-5` | low |
| `standard` | `router-builder` | `claude-sonnet-5-5` | medium |
| `strong` | `router-architect` (work), `router-reviewer` (review) | `claude-opus-5-5` | high |
| `frontier` | `router-deep-thinker` | `claude-fable-5-2` | high |

Cursor agent frontmatter has no effort field, so effort is guidance for the brief only. The frontier tier is gated: call `router-deep-thinker` only after the user approves it in this chat.

## 3. Preset agents

Files: `router-{scout,builder,architect,reviewer,deep-thinker}.md`, in the adapter folder at https://github.com/knightsfork/agent-model-router/tree/main/adapters/cursor/agents (the `adapters/` folder isn't installed with the skill).

- User install: `~/.cursor/agents/`
- Project install: `.cursor/agents/`

Frontmatter fields: `name`, `description`, `model`, `readonly`.

- `router-scout`, `router-builder` and `router-architect` use `readonly: false`, because they write files.
- `router-reviewer` and `router-deep-thinker` use `readonly: true`, so they can read and report but not edit.

Call a preset by its `name`. Whether names are the file base names in lowercase is unconfirmed; use the name exactly as Cursor's agent list shows it.

## 4. Platform caveats

- The model is fixed per definition. To use a different model for a tier, edit that agent's file.
- Cursor also reads `.claude/agents` and `.codex/agents`. If the same agent name exists in several folders, the versions in `.cursor/agents` win. If you use several tools, install each tool's adapter in its own folder.
- A slug that your plan doesn't offer may fail or fall back. If a spawn fails on the model, report it to the user and run the part on the nearest tier that works.
- `readonly: true` limits edits, not what the agent says. The body text still tells reviewers and the deep thinker not to edit.
- The scout is `readonly: false` only so it can write the single output file named in the brief.

## 5. How to change the models

1. Open the preset file in `.cursor/agents/` or `~/.cursor/agents/`.
2. Change the `model` value to a slug from your plan's model list.
3. Use `inherit` to follow the main chat's model.
4. Start a new chat so Cursor reloads the agent definitions.

## 6. Sources

- https://cursor.com/docs/subagents
- https://cursor.com/docs/models

Model slugs are taken from cursor.com/docs/models as of November 2026.

## 7. Verified

Follows the vendor's documented format; not yet run end to end. Please report results.
