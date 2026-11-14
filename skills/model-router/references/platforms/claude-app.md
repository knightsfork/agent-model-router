# Platform reference: Claude apps (`claude-app`)

Read this once per session when you run in the Claude desktop, web or mobile app and have the agent tools. Without subagent tools, the skill works inline (Step 0).

## 1. How to spawn a subagent with a chosen model

Use the Agent tool, the same one Claude Code has. Set `model` and `effort` on every call:

- `model`: `haiku`, `sonnet`, `opus` or `fable`
- `effort`: `low`, `medium`, `high`, `xhigh` or `max`
- `subagent_type`: `"general-purpose"`, or `"Explore"` and `"Plan"` where offered. **Never use `subagent_type: "fork"`.** Fork subagents inherit the parent's model and ignore `model`, so the routing silently does nothing.

Run independent parts in parallel by issuing the Agent calls in one message, up to `max_parallel_agents`.

## 2. Tier-to-model table

| Tier | `model` | `effort` |
|---|---|---|
| fast | `haiku` | low |
| standard | `sonnet` | medium |
| strong | `opus` | high |
| frontier | `fable` | high (only after user approval) |

The mapping is the same as Claude Code. Check the model list for your own plan.

## 3. Preset agents

None. The apps don't load `.claude/agents`, so the `router-*` agents don't exist here. Route with general-purpose agents and set `model` and `effort` on every call. Put the role text for the tier from `references/brief-templates.md` at the top of the brief, so the agent gets the same instructions a preset would carry.

- The gate still applies: do not spawn a `fable` agent before the user approves the frontier tier for that part.

## 4. Caveats

- Subagents depend on the user's plan and app features. If the Agent tool isn't there, work inline.
- Fork subagents ignore `model`. Never route through them.
- Ask for approval with the AskUserQuestion tool. If it fails or is missing, ask in plain chat and wait.
- Subagents return only a final message. Have them write large outputs to the files the brief names.

## 5. How to change the models

Change the `model` and `effort` values you pass in Agent calls, and edit the tier table in this file. Re-upload the zip afterwards (see the README).

## 6. Install

Upload a zip of the `model-router` folder (with `SKILL.md` inside it) as a custom skill in Claude's skill settings. Skills trigger automatically from the description. `./install.sh claude-app` builds the zip at `dist/model-router.zip`.

## 7. Sources

- https://code.claude.com/docs/en/sub-agents (the Agent tool is shared with Claude Code)

## Verified

Used in live sessions in the Claude desktop app.
